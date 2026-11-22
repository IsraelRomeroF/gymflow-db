import 'dotenv/config';
import {
  anchoredDate, formatMemberCode, memberCodePrefix, normalizedNameKey, normalizePhoneMx, uuidv7,
} from '@gymflow/core';
import { createPrismaClient } from './client.js';

/**
 * Volumen REPRESENTATIVO para verificar el criterio de aceptación del
 * Sprint 2: "buscar un socio por nombre con errores de captura toma < 1 s".
 *
 * Un índice que va rápido con 20 filas no prueba nada. El gimnasio confirmado
 * tiene 1,500+ socios activos y, contando históricos, el padrón llega a
 * varios miles (docs/00 §S07).
 */
const db = createPrismaClient(process.env.DATABASE_URL_MIGRATOR);

const NOMBRES = ['José','María','Guadalupe','Juan','Ana','Luis','Carmen','Miguel','Rosa','Carlos','Patricia','Jorge','Laura','Pedro','Alejandra','Francisco','Sofía','Ricardo','Gabriela','Antonio','Verónica','Fernando','Mónica','Roberto','Claudia','Alejandro','Adriana','Daniel','Leticia','Javier','Norma','Manuel','Silvia','Arturo','Beatriz','Sergio','Rocío','Eduardo','Martha','Raúl'];
const APELLIDOS = ['Hernández','García','Martínez','López','González','Pérez','Rodríguez','Sánchez','Ramírez','Cruz','Flores','Gómez','Morales','Vázquez','Reyes','Jiménez','Torres','Díaz','Gutiérrez','Ruiz','Mendoza','Aguilar','Ortiz','Castillo','Romero','Álvarez','Chávez','Ramos','Herrera','Medina','Rojas','Vargas','Castro','Guerrero','Ríos','Domínguez','Salazar','Contreras','Luna','Estrada'];

const COUNT = Number(process.env.SEED_VOLUME_COUNT ?? 3000);

function pick<T>(arr: readonly T[], i: number): T { return arr[i % arr.length]!; }

async function main() {
  const org = await db.organization.findFirst({ where: { tradeName: 'Gimnasio Demo' } });
  if (!org) throw new Error('Falta la organización de demo: corre antes `seed:demo`');
  const branches = await db.branch.findMany({ where: { organizationId: org.id }, orderBy: { code: 'asc' } });

  const existing = await db.member.count({ where: { organizationId: org.id } });
  console.log(`Socios actuales: ${existing}. Generando ${COUNT}…`);

  const rows: Array<Record<string, unknown>> = [];
  for (let i = 0; i < COUNT; i++) {
    const first = `${pick(NOMBRES, i * 7)} ${pick(NOMBRES, i * 13 + 3)}`;
    const last = `${pick(APELLIDOS, i * 11)} ${pick(APELLIDOS, i * 17 + 5)}`;
    const branch = pick(branches, i);
    const seq = existing + i + 1;
    // Teléfonos únicos y válidos: el índice único parcial los exige.
    const phone = normalizePhoneMx(`55${String(10_000_000 + seq).slice(0, 8)}`);
    rows.push({
      id: uuidv7(),
      organizationId: org.id,
      memberCode: formatMemberCode(branch.code, seq),
      homeBranchId: branch.id,
      firstName: first,
      lastName: last,
      nameKey: normalizedNameKey(`${first} ${last}`),
      phoneE164: phone,
      email: `socio${seq}@ejemplo.mx`,
      status: i % 9 === 0 ? 'INACTIVE' : 'ACTIVE',
      joinedAt: new Date(Date.now() - (i % 900) * 86_400_000),
      balanceCentsCached: 0n,
    });
  }

  const BATCH = 500;
  for (let i = 0; i < rows.length; i += BATCH) {
    await db.member.createMany({ data: rows.slice(i, i + BATCH) as never, skipDuplicates: true });
    process.stdout.write(`\r  insertados ${Math.min(i + BATCH, rows.length)}/${rows.length}`);
  }
  console.log('');

  // TODA carga masiva debe dejar el contador de códigos al día. Omitirlo
  // hace que la siguiente alta manual colisione — es el error que la
  // migración de BDKGYM cometería si no se documenta.
  // Por PREFIJO, igual que el alta: varias sucursales pueden compartirlo y el
  // contador tiene que cubrir a todas.
  const prefijos = new Set(branches.map((b) => memberCodePrefix(b.code)));
  for (const prefix of prefijos) {
    // Mismo criterio que el alta: solo códigos con el formato propio.
    const pattern = `^${prefix}-[0-9]{1,6}$`;
    const max = await db.$queryRaw<Array<{ max: number | null }>>`
      SELECT MAX(split_part("memberCode", '-', 2)::int) AS max
      FROM members
      WHERE "organizationId" = ${org.id}::uuid
        AND "memberCode" ~ ${pattern}`;
    const last = max[0]?.max ?? 0;
    await db.memberCodeCounter.upsert({
      where: { organizationId_prefix: { organizationId: org.id, prefix } },
      create: { organizationId: org.id, prefix, lastSequence: last },
      update: { lastSequence: last },
    });
  }
  console.log('  contadores de código actualizados');

  // ANALYZE: sin estadísticas frescas el planificador puede ignorar el índice
  // GIN y hacer un recorrido secuencial, lo que falsearía la medición.
  await db.$executeRawUnsafe('ANALYZE members');

  // ── Membresías ────────────────────────────────────────────────────────────
  // Se reparten entre los estados reales del motor para que los jobs diarios
  // y los reportes tengan algo que procesar desde el primer arranque.
  const planes = await db.plan.findMany({
    where: { organizationId: org.id, billingModel: { in: ['RECURRING', 'PREPAID_PERIOD'] }, deletedAt: null },
  });
  const sinMembresia = await db.member.findMany({
    where: { organizationId: org.id, deletedAt: null, memberships: { none: {} } },
    select: { id: true, homeBranchId: true },
    take: COUNT,
  });

  const hoy = new Date();
  const membresias = sinMembresia.map((m, i) => {
    const plan = planes[i % planes.length]!;
    const ancla = (i % 28) + 1;
    const inicio = new Date(Date.UTC(hoy.getUTCFullYear(), hoy.getUTCMonth() - 1, Math.min(ancla, 28)));
    const fin = anchoredDate(ancla, hoy.getUTCFullYear(), hoy.getUTCMonth() + 1);
    // 1 de cada 12 queda vencida a propósito: sin morosos, la cartera y el
    // dunning no se pueden probar.
    const vencida = i % 12 === 0;
    return {
      id: uuidv7(),
      organizationId: org.id,
      memberId: m.id,
      planId: plan.id,
      soldAtBranchId: m.homeBranchId,
      status: (vencida ? 'PAST_DUE' : 'ACTIVE') as 'PAST_DUE' | 'ACTIVE',
      startDate: inicio,
      currentPeriodStart: inicio,
      currentPeriodEnd: vencida ? new Date(hoy.getTime() - 3 * 86_400_000) : fin,
      billingAnchorDay: ancla,
      graceUntil: vencida ? new Date(hoy.getTime() + 2 * 86_400_000) : null,
      autoRenew: plan.billingModel === 'RECURRING',
    };
  });

  for (let i = 0; i < membresias.length; i += BATCH) {
    await db.membership.createMany({ data: membresias.slice(i, i + BATCH) as never, skipDuplicates: true });
  }
  await db.$executeRawUnsafe('ANALYZE memberships');

  const total = await db.member.count({ where: { organizationId: org.id } });
  const activas = await db.membership.count({ where: { organizationId: org.id, status: 'ACTIVE' } });
  const morosas = await db.membership.count({ where: { organizationId: org.id, status: 'PAST_DUE' } });
  console.log(`Total de socios: ${total}`);
  console.log(`Membresías: ${activas} activas, ${morosas} en mora`);
}

main()
  .catch((err) => { console.error('ERROR:', err); process.exit(1); })
  .finally(() => db.$disconnect());
