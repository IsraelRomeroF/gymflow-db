import 'dotenv/config';
import { PERMISSIONS, RETIRED_ROLES, ROLES, uuidv7 } from '@gymflow/core';
import { createPrismaClient } from './client.js';
import { EJERCICIOS } from './exercises.js';

/**
 * Siembra el CATÁLOGO del sistema: permisos y roles de sistema.
 *
 * Es idempotente y obligatorio en todos los entornos: sin él, `can()` no
 * puede resolver ninguna concesión. No crea datos de negocio.
 *
 * Se ejecuta con el rol propietario porque escribe catálogo de plataforma.
 */
const db = createPrismaClient(process.env.DATABASE_URL_MIGRATOR);

async function main() {
  console.log('Sembrando catálogo de permisos y roles de sistema…\n');

  // ── Permisos ──────────────────────────────────────────────────────────────
  for (const perm of PERMISSIONS) {
    await db.permission.upsert({
      where: { key: perm.key },
      create: {
        key: perm.key,
        domain: perm.domain,
        description: perm.description,
        requiresReason: perm.requiresReason,
        requiresApproval: perm.requiresApproval,
      },
      update: {
        domain: perm.domain,
        description: perm.description,
        requiresReason: perm.requiresReason,
        requiresApproval: perm.requiresApproval,
      },
    });
  }
  console.log(`  permisos: ${PERMISSIONS.length}`);

  // Un permiso que desaparece del catálogo debe desaparecer de la base:
  // si no, queda concedido a alguien y nadie lo sabe.
  const validKeys = PERMISSIONS.map((p) => p.key);
  const removed = await db.permission.deleteMany({ where: { key: { notIn: validKeys } } });
  if (removed.count > 0) console.log(`  permisos retirados del catálogo: ${removed.count}`);

  // ── Roles de sistema: el catálogo de puestos de `@gymflow/core` (ADR-039) ──
  for (const def of ROLES) {
    const { key } = def;
    const existing = await db.role.findFirst({ where: { organizationId: null, key } });
    const role = existing
      ? await db.role.update({ where: { id: existing.id }, data: { name: def.name } })
      : await db.role.create({
          data: { id: uuidv7(), organizationId: null, key, name: def.name, isSystem: true },
        });

    const desired = new Set<string>(def.permissions);
    const current = await db.rolePermission.findMany({ where: { roleId: role.id } });
    const currentKeys = new Set(current.map((rp) => rp.permissionKey));

    const toAdd = [...desired].filter((k) => !currentKeys.has(k));
    const toRemove = [...currentKeys].filter((k) => !desired.has(k));

    if (toAdd.length > 0) {
      await db.rolePermission.createMany({
        data: toAdd.map((permissionKey) => ({ roleId: role.id, permissionKey })),
        skipDuplicates: true,
      });
    }
    if (toRemove.length > 0) {
      await db.rolePermission.deleteMany({ where: { roleId: role.id, permissionKey: { in: toRemove } } });
    }

    console.log(
      `  rol ${key.padEnd(10)} ${desired.size} permisos` +
        (toAdd.length ? ` (+${toAdd.length})` : '') +
        (toRemove.length ? ` (-${toRemove.length})` : ''),
    );
  }

  // ── Puestos retirados (2026-10-05): la gente pasa al puesto que los absorbe ──
  for (const [viejo, nuevo] of Object.entries(RETIRED_ROLES)) {
    const rolViejo = await db.role.findFirst({ where: { organizationId: null, key: viejo } });
    if (!rolViejo) continue;
    const rolNuevo = await db.role.findFirstOrThrow({ where: { organizationId: null, key: nuevo } });
    const asignaciones = await db.roleAssignment.findMany({ where: { roleId: rolViejo.id } });
    let pasados = 0;
    for (const a of asignaciones) {
      const yaTiene = a.revokedAt === null && await db.roleAssignment.findFirst({ where: { userId: a.userId, roleId: rolNuevo.id, branchId: a.branchId, revokedAt: null } });
      if (yaTiene) await db.roleAssignment.update({ where: { id: a.id }, data: { revokedAt: new Date() } });
      await db.roleAssignment.update({ where: { id: a.id }, data: { roleId: rolNuevo.id } });
      pasados++;
    }
    await db.roleLimitSet.deleteMany({ where: { roleId: rolViejo.id } });
    await db.rolePermission.deleteMany({ where: { roleId: rolViejo.id } });
    await db.role.delete({ where: { id: rolViejo.id } });
    console.log(`  puesto retirado ${viejo} → ${nuevo} (${pasados} asignaciones)`);
  }

  // ── Un solo gerente (2026-10-06): el acotado a sucursales pasa a todo el gimnasio ──
  // Por persona queda UNA asignación de alcance general; las de sucursal se
  // revocan. Idempotente: en una base ya al día no cambia nada.
  {
    const gerente = await db.role.findFirst({ where: { organizationId: null, key: 'MANAGER' } });
    if (gerente) {
      const acotadas = await db.roleAssignment.findMany({ where: { roleId: gerente.id, revokedAt: null, branchId: { not: null } } });
      const personas = new Map<string, typeof acotadas>();
      for (const a of acotadas) personas.set(a.userId, [...(personas.get(a.userId) ?? []), a]);
      for (const [userId, xs] of personas) {
        const general = await db.roleAssignment.findFirst({ where: { userId, roleId: gerente.id, branchId: null, revokedAt: null } });
        if (!general) await db.roleAssignment.create({ data: { id: uuidv7(), organizationId: xs[0]!.organizationId, userId, roleId: gerente.id, branchId: null } });
        await db.roleAssignment.updateMany({ where: { id: { in: xs.map((x) => x.id) } }, data: { revokedAt: new Date() } });
      }
      if (personas.size > 0) console.log(`  gerentes acotados → todo el gimnasio: ${personas.size}`);
    }
  }

  // ── Ejercicios del catálogo global ────────────────────────────────────────
  // Diez por bloque muscular, sin organización: los ve todo gimnasio y ninguno
  // los edita. Por `code`, sembrar dos veces actualiza en vez de duplicar.
  for (const e of EJERCICIOS) {
    await db.exercise.upsert({
      where: { code: e.code },
      create: { id: uuidv7(), organizationId: null, ...e },
      update: { name: e.name, muscleGroup: e.muscleGroup, equipment: e.equipment, instructions: e.instructions },
    });
  }
  console.log(`  ejercicios: ${EJERCICIOS.length} en ${new Set(EJERCICIOS.map((e) => e.muscleGroup)).size} bloques`);

  console.log('\nCatálogo sembrado.');
}

main()
  .catch((err) => {
    console.error('ERROR en el seed:', err);
    process.exit(1);
  })
  .finally(() => db.$disconnect());
