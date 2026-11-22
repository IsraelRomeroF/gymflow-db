import 'dotenv/config';
import { hash as argonHash } from '@node-rs/argon2';
import { uuidv7, ROLES, type RoleKey, LOCKABLE_SECTIONS } from '@gymflow/core';
import { createHash } from 'node:crypto';
import { createPrismaClient } from './client.js';

/**
 * Datos de DESARROLLO. No se ejecuta en producción.
 *
 * Crea DOS organizaciones a propósito: sin una segunda, la prueba de
 * aislamiento de tenant no prueba nada.
 */
const db = createPrismaClient(process.env.DATABASE_URL_MIGRATOR);
const PASSWORD = 'GymFlow.dev.2026';

async function ensureOrg(name: string, trade: string, branches: Array<{ code: string; name: string; tz?: string }>) {
  const existing = await db.organization.findFirst({ where: { tradeName: trade } });
  const org = existing ?? (await db.organization.create({
    data: { id: uuidv7(), legalName: name, tradeName: trade },
  }));

  const created: Record<string, string> = {};
  for (const b of branches) {
    const found = await db.branch.findFirst({ where: { organizationId: org.id, code: b.code, deletedAt: null } });
    const branch = found ?? (await db.branch.create({
      data: { id: uuidv7(), organizationId: org.id, code: b.code, name: b.name, timezone: b.tz ?? null },
    }));
    created[b.code] = branch.id;
  }

  // Topes por puesto para esta organización: los del catálogo (ADR-039).
  for (const def of ROLES) {
    const role = await db.role.findFirst({ where: { organizationId: null, key: def.key } });
    if (!role) continue;
    const limits = def.limits;
    const existingSet = await db.roleLimitSet.findFirst({ where: { organizationId: org.id, roleId: role.id } });
    if (existingSet) {
      await db.roleLimitSet.update({ where: { id: existingSet.id }, data: limits as never });
    } else {
      await db.roleLimitSet.create({ data: { id: uuidv7(), organizationId: org.id, roleId: role.id, ...limits } as never });
    }
  }

  return { org, branches: created };
}

async function ensureUser(
  organizationId: string,
  email: string,
  fullName: string,
  roleKey: RoleKey,
  branchIds: Array<string | null>,
) {
  const passwordHash = await argonHash(PASSWORD, { memoryCost: 19456, timeCost: 2, parallelism: 1 });
  const found = await db.user.findFirst({ where: { organizationId, email, deletedAt: null } });
  const user = found ?? (await db.user.create({
    data: { id: uuidv7(), organizationId, email, fullName, passwordHash },
  }));

  const role = await db.role.findFirst({ where: { organizationId: null, key: roleKey } });
  if (!role) throw new Error(`Rol de sistema ${roleKey} no sembrado: corre primero el seed de catálogo`);

  // El puesto y el alcance de aquí mandan: lo que tuviera de antes se revoca
  // (así una base vieja se pone al día al volver a sembrar).
  await db.user.update({ where: { id: user.id }, data: { fullName } });
  const vigentes = await db.roleAssignment.findMany({ where: { userId: user.id, revokedAt: null }, select: { id: true, roleId: true, branchId: true } });
  const sobran = vigentes.filter((a) => a.roleId !== role.id || !branchIds.includes(a.branchId)).map((a) => a.id);
  if (sobran.length > 0) await db.roleAssignment.updateMany({ where: { id: { in: sobran } }, data: { revokedAt: new Date() } });
  for (const branchId of branchIds) {
    const exists = await db.roleAssignment.findFirst({
      where: { userId: user.id, roleId: role.id, branchId, revokedAt: null },
    });
    if (!exists) {
      await db.roleAssignment.create({
        data: { id: uuidv7(), organizationId, userId: user.id, roleId: role.id, branchId },
      });
    }
  }
  return user;
}

/**
 * Catálogo de planes de desarrollo.
 *
 * `taxRateBps: null` refleja la realidad de hoy: no se factura y no se
 * desglosa impuesto. Cuando se responda Q-B-04 basta con fijar la tasa y
 * `priceIncludesTax`; los importes NO cambian y no hay que migrar datos.
 */
async function ensurePlans(organizationId: string, branchIds: Record<string, string>) {
  const plans = [
    { code: 'MEN',  name: 'Mensualidad',        billingModel: 'RECURRING',      durationUnit: 'MONTH', durationValue: 1,  priceCents: 65_000n,  signupFeeCents: 30_000n, branchAccessScope: 'HOME_BRANCH' },
    { code: 'MEN3', name: 'Trimestral',         billingModel: 'RECURRING',      durationUnit: 'MONTH', durationValue: 3,  priceCents: 180_000n, signupFeeCents: 30_000n, branchAccessScope: 'HOME_BRANCH' },
    { code: 'ANU',  name: 'Anualidad',          billingModel: 'PREPAID_PERIOD', durationUnit: 'MONTH', durationValue: 12, priceCents: 650_000n, signupFeeCents: 0n,      branchAccessScope: 'ALL_BRANCHES' },
    { code: 'MULTI',name: 'Multisede mensual',  billingModel: 'RECURRING',      durationUnit: 'MONTH', durationValue: 1,  priceCents: 89_000n,  signupFeeCents: 30_000n, branchAccessScope: 'ALL_BRANCHES' },
    { code: 'V10',  name: 'Paquete 10 visitas', billingModel: 'VISIT_PACK',     durationUnit: 'VISIT', durationValue: 10, priceCents: 120_000n, signupFeeCents: 0n,      branchAccessScope: 'HOME_BRANCH', visitsIncluded: 10, visitValidityDays: 90 },
    { code: 'DAY',  name: 'Visita suelta',      billingModel: 'DAY_PASS',       durationUnit: 'DAY',   durationValue: 1,  priceCents: 15_000n,  signupFeeCents: 0n,      branchAccessScope: 'HOME_BRANCH' },
  ] as const;

  for (const plan of plans) {
    const found = await db.plan.findFirst({ where: { organizationId, code: plan.code, deletedAt: null } });
    const data = {
      ...plan,
      organizationId,
      taxRateBps: null,
      allowFreeze: plan.billingModel === 'RECURRING' || plan.billingModel === 'PREPAID_PERIOD',
    };
    const saved = found
      ? await db.plan.update({ where: { id: found.id }, data: data as never })
      : await db.plan.create({ data: { id: uuidv7(), ...data } as never });

    // El plan de una sola sede se ofrece en todas, con precio propio en
    // Frontera: es la excepción documentada de §25.
    for (const [code, branchId] of Object.entries(branchIds)) {
      const exists = await db.planBranchAvailability.findFirst({ where: { planId: saved.id, branchId } });
      const override = code === 'FRO' && plan.billingModel === 'RECURRING'
        ? (plan.priceCents * 110n) / 100n
        : null;
      if (!exists) {
        await db.planBranchAvailability.create({
          data: { planId: saved.id, branchId, organizationId, priceOverrideCents: override },
        });
      }
    }
  }
  return plans.length;
}

/**
 * Cajas de mostrador. El Centro lleva DOS a propósito: es el caso que obliga
 * a elegir turno al cobrar, y sin él esa rama no se ejercita nunca.
 */
async function ensureRegisters(
  organizationId: string,
  branches: Record<string, string>,
): Promise<number> {
  const plan: Array<{ branch: string; code: string; name: string }> = [];
  const codigos = Object.keys(branches);
  for (const code of codigos) {
    plan.push({ branch: code, code: 'C1', name: `Caja 1 ${code}` });
    if (code === 'CEN') plan.push({ branch: code, code: 'C2', name: 'Caja 2 Centro' });
  }

  let n = 0;
  for (const r of plan) {
    const branchId = branches[r.branch];
    if (!branchId) continue;
    const found = await db.cashRegister.findFirst({
      where: { organizationId, branchId, code: r.code, deletedAt: null },
    });
    if (!found) {
      await db.cashRegister.create({
        data: { id: uuidv7(), organizationId, branchId, code: r.code, name: r.name },
      });
    }
    n++;
  }
  return n;
}

/**
 * Catálogo de mostrador.
 *
 * Los precios son de DESARROLLO, igual que los de los planes: sirven para que
 * el corte tenga algo que sumar, no son una recomendación comercial.
 */
async function ensureProducts(
  organizationId: string,
  branches: Record<string, string>,
): Promise<number> {
  const catalogo = [
    { sku: 'AGUA600', name: 'Agua 600 ml', priceCents: 1500n, stock: 120 },
    { sku: 'BEBIDA-ISO', name: 'Bebida isotónica', priceCents: 3000n, stock: 60 },
    { sku: 'PROTEINA-SHOT', name: 'Shot de proteína', priceCents: 6500n, stock: 40 },
    { sku: 'BARRA-CEREAL', name: 'Barra de cereal', priceCents: 2500n, stock: 80 },
    { sku: 'TOALLA', name: 'Toalla de cortesía', priceCents: 8000n, stock: 25 },
    // Un servicio NO lleva existencias: es el caso que obliga a que el
    // inventario sea opcional por producto.
    { sku: 'CASILLERO-DIA', name: 'Casillero por día', priceCents: 2000n, stock: null },
  ];

  let n = 0;
  for (const p of catalogo) {
    let product = await db.product.findFirst({
      where: { organizationId, sku: p.sku, deletedAt: null },
    });
    if (!product) {
      product = await db.product.create({
        data: {
          id: uuidv7(), organizationId, sku: p.sku, name: p.name,
          priceCents: p.priceCents, tracksInventory: p.stock !== null,
        },
      });
    }
    n++;

    if (p.stock === null) continue;
    for (const branchId of Object.values(branches)) {
      const existe = await db.inventoryStock.findFirst({
        where: { branchId, productId: product.id },
      });
      if (existe) continue;
      await db.inventoryStock.create({
        data: { organizationId, branchId, productId: product.id, quantityOnHand: p.stock },
      });
      await db.inventoryMovement.create({
        data: {
          id: uuidv7(), organizationId, branchId, productId: product.id,
          movementType: 'PURCHASE', quantityDelta: p.stock,
          reason: 'Carga inicial de datos de desarrollo',
          createdByUserId: (await db.user.findFirstOrThrow({ where: { organizationId } })).id,
          businessDate: new Date(),
        },
      });
    }
  }
  return n;
}

/**
 * Planes: se marca cuáles INCLUYEN clases.
 *
 * Falso por defecto en el esquema a propósito —regalar clases por omisión es
 * un error que solo se descubre al cuadrar el mes—, así que aquí se dice
 * explícitamente cuáles sí.
 */
const PLANES_CON_CLASES = ['ANU', 'MULTI'];

/**
 * Clases de demostración: dos tipos y sus horarios semanales.
 *
 * El horario se siembra en la sede FRONTERIZA además de en el Centro. No es
 * relleno: es la única sede que cambia de hora, y tenerla poblada desde el
 * día 1 es lo que hace visible si el generador resuelve mal el desfase.
 */
async function ensureClasses(organizationId: string, branchIds: Record<string, string>) {
  const tipos = [
    { name: 'Spinning',   defaultDurationMin: 45, defaultCapacity: 16, dropInPriceCents: 15_000n },
    { name: 'Funcional',  defaultDurationMin: 60, defaultCapacity: 20, dropInPriceCents: 12_000n },
  ] as const;

  const ids: Record<string, string> = {};
  for (const tipo of tipos) {
    const found = await db.classType.findFirst({ where: { organizationId, name: tipo.name, deletedAt: null } });
    const saved = found ?? await db.classType.create({
      data: { id: uuidv7(), organizationId, ...tipo },
    });
    ids[tipo.name] = saved.id;
  }

  const horarios = [
    { tipo: 'Spinning',  branch: 'CEN', room: 'Salón 1', slots: [1, 3, 5].map((weekday) => ({ weekday, startMinute: 7 * 60, durationMin: 45, capacity: 16 })) },
    { tipo: 'Funcional', branch: 'CEN', room: 'Salón 2', slots: [2, 4].map((weekday) => ({ weekday, startMinute: 19 * 60, durationMin: 60, capacity: 20 })) },
    { tipo: 'Spinning',  branch: 'FRO', room: 'Único',   slots: [1, 3].map((weekday) => ({ weekday, startMinute: 7 * 60, durationMin: 45, capacity: 12 })) },
  ];

  let plantillas = 0;
  for (const h of horarios) {
    const branchId = branchIds[h.branch];
    const classTypeId = ids[h.tipo];
    if (!branchId || !classTypeId) continue;

    const existing = await db.classTemplate.findFirst({ where: { organizationId, branchId, classTypeId } });
    if (existing) continue;

    const template = await db.classTemplate.create({
      data: {
        id: uuidv7(), organizationId, branchId, classTypeId, room: h.room,
        effectiveFrom: new Date(new Date().toISOString().slice(0, 10)),
      },
    });
    for (const slot of h.slots) {
      await db.classTemplateSlot.create({ data: { id: uuidv7(), templateId: template.id, ...slot } });
    }
    plantillas += 1;
  }
  return plantillas;
}

/**
 * Textos de consentimiento de DEMOSTRACIÓN.
 *
 * Se publican para que el alta digital y el enrolamiento se puedan recorrer de
 * punta a punta en desarrollo, y **el propio texto dice que es de
 * demostración**. El texto real lo redacta y lo publica el dueño desde el
 * panel (no habrá dictamen externo: P5 quedó fuera del alcance el
 * 2026-09-28); publicar aquí algo que pareciera definitivo confundiría cuál
 * es el vigente.
 *
 * Esto NO se ejecuta en producción: es el sembrado de desarrollo.
 */
async function ensureConsentDocs(organizationId: string) {
  const docs = [
    { consentType: 'PRIVACY_NOTICE', title: 'Aviso de privacidad' },
    { consentType: 'HOUSE_RULES', title: 'Reglamento interno' },
    { consentType: 'HEALTH_DATA', title: 'Datos de salud (opcional)' },
    // Lo exige el enrolamiento (ADR-032): sin texto BIOMETRIC publicado no se
    // puede enrolar a nadie.
    { consentType: 'BIOMETRIC', title: 'Consentimiento biométrico' },
  ] as const;

  let publicados = 0;
  for (const doc of docs) {
    const vigente = await db.consentDocument.findFirst({
      where: { organizationId, consentType: doc.consentType, status: 'PUBLISHED' },
    });
    if (vigente) continue;

    const bodyText = [
      '⚠ TEXTO DE DEMOSTRACIÓN.',
      '',
      `Marcador de posición para "${doc.title}". El texto definitivo lo redacta`,
      'el gimnasio, no el equipo de desarrollo.',
      '',
      'Existe para poder recorrer el alta digital en desarrollo. En producción,',
      'el documento correspondiente se crea y se publica desde el panel, con su',
      'motivo.',
    ].join('\n');

    const created = await db.consentDocument.create({
      data: {
        id: uuidv7(), organizationId, consentType: doc.consentType,
        version: 'demo-1', title: `${doc.title} (DEMO)`, bodyText, status: 'DRAFT',
      },
    });
    await db.consentDocument.update({
      where: { id: created.id },
      data: {
        status: 'PUBLISHED',
        publishedAt: new Date(),
        bodyHash: createHash('sha256').update(bodyText).digest('hex'),
      },
    });
    publicados += 1;
  }
  return publicados;
}

async function main() {
  console.log('Sembrando datos de desarrollo…\n');

  const demo = await ensureOrg('Gimnasio Demo S.A. de C.V.', 'Gimnasio Demo', [
    { code: 'CEN', name: 'Centro' },
    { code: 'NOR', name: 'Norte' },
    // Sucursal fronteriza: zona horaria DISTINTA. Existe para que el caso
    // del horario estacional esté representado desde el día 1 (ADR-006).
    { code: 'FRO', name: 'Frontera', tz: 'America/Tijuana' },
  ]);

  const other = await ensureOrg('Otro Gimnasio S.A.', 'Otro Gimnasio', [{ code: 'UNI', name: 'Única' }]);

  await ensureUser(demo.org.id, 'owner@demo.mx', 'Dueño Demo', 'OWNER', [null]);
  // Cuatro puestos (2026-10-05): dueño, gerente, recepción y coach. Un
  // gerente puede llevar todo el gimnasio o solo algunas sucursales; la
  // segunda firma la da el dueño desde su teléfono.
  await ensureUser(demo.org.id, 'gerencia@demo.mx', 'Gerencia General', 'MANAGER', [null]);
  // Un segundo gerente, también de todo el gimnasio (2026-10-06: ya no hay
  // gerente acotado a sucursales). Las pruebas lo usan como "el otro gerente".
  await ensureUser(demo.org.id, 'gerente@demo.mx', 'Segundo Gerente', 'MANAGER', [null]);
  await ensureUser(demo.org.id, 'recepcion@demo.mx', 'Recepción Centro', 'RECEPTION', [demo.branches['CEN']!]);
  // La llave del dueño (2026-10-06): a los dos gerentes de ensayo les deja
  // Dirección y Cumplimiento completos; a recepción, nada.
  await db.user.updateMany({ where: { organizationId: demo.org.id, email: { in: ['gerencia@demo.mx', 'gerente@demo.mx'] } }, data: { unlockedSections: LOCKABLE_SECTIONS.filter((x) => !x.defaultOpen).map((x) => x.key) } });
  await db.user.updateMany({ where: { organizationId: demo.org.id, email: 'recepcion@demo.mx' }, data: { unlockedSections: [] } });
  await ensureUser(demo.org.id, 'coach@demo.mx', 'Coach Demo', 'COACH', [null]);
  // Cuentas de puestos que ya no existen: se dan de baja.
  await db.user.updateMany({
    where: { organizationId: demo.org.id, email: { in: ['encargado@demo.mx', 'caja@demo.mx', 'profesor@demo.mx'] }, deletedAt: null },
    data: { deletedAt: new Date(), isActive: false },
  });
  await ensureUser(other.org.id, 'owner@otro.mx', 'Dueño Otro', 'OWNER', [null]);
  await ensureUser(other.org.id, 'gerencia@otro.mx', 'Gerencia Otro', 'MANAGER', [null]);
  await db.user.updateMany({ where: { organizationId: other.org.id, email: 'gerencia@otro.mx' }, data: { unlockedSections: LOCKABLE_SECTIONS.filter((x) => !x.defaultOpen).map((x) => x.key) } });

  // Quien opera la PLATAFORMA: no pertenece a ningún gimnasio. Da de alta
  // marcas nuevas desde el panel de plataforma (ADR-037).
  if (!(await db.user.findFirst({ where: { organizationId: null, email: 'plataforma@gymflow.mx', deletedAt: null } }))) {
    await db.user.create({
      data: {
        id: uuidv7(), organizationId: null, email: 'plataforma@gymflow.mx', fullName: 'Soporte GymFlow',
        passwordHash: await argonHash(PASSWORD, { memoryCost: 19456, timeCost: 2, parallelism: 1 }),
      },
    });
  }

  const planCount = await ensurePlans(demo.org.id, demo.branches);
  await ensurePlans(other.org.id, other.branches);

  const registerCount = await ensureRegisters(demo.org.id, demo.branches);
  await ensureRegisters(other.org.id, other.branches);

  const productCount = await ensureProducts(demo.org.id, demo.branches);
  await ensureProducts(other.org.id, other.branches);

  // Marca qué planes traen las clases incluidas. Sin esto, TODOS cobrarían
  // clase suelta, que es el valor por defecto del esquema.
  await db.plan.updateMany({
    where: { organizationId: demo.org.id, code: { in: PLANES_CON_CLASES } },
    data: { includesClasses: true },
  });

  const classCount = await ensureClasses(demo.org.id, demo.branches);
  const consentCount = await ensureConsentDocs(demo.org.id);

  console.log(`  ${demo.org.tradeName}: ${Object.keys(demo.branches).length} sucursales, 4 usuarios, ${planCount} planes, ${registerCount} cajas, ${productCount} productos`);
  console.log(`  ${demo.org.tradeName}: ${classCount} horarios de clase, ${consentCount} textos de consentimiento (DEMO)`);
  console.log(`  ${other.org.tradeName}: 1 sucursal, 1 usuario`);
  console.log(`\n  contraseña de todos: ${PASSWORD}`);
  console.log('\nDatos de desarrollo sembrados.');
}

main()
  .catch((err) => { console.error('ERROR:', err); process.exit(1); })
  .finally(() => db.$disconnect());
