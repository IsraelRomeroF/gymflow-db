-- Auditoría 8 · fase 4 · bloque 4.20 · P-14: un AUMENTO del precio de un plan
-- pide un mínimo de 15 días entre el día en que se guarda y el primer cobro con
-- el precio nuevo. La regla vive en el núcleo (`aviso-de-aumento.ts`) y en la
-- emisión de la cuota (`billing.createPeriodCharge`): el aumento queda guardado
-- «por llegar» en `membership_price_changes` y el precio pactado de la
-- membresía se mueve hasta que se emite la primera cuota que ya lo lleva.
--
-- NO ES ADITIVA: además de columnas y una tabla nuevas, el paso 4 ESCRIBE en
-- filas que ya existen (`membership_price_changes` y `memberships`). Qué toca,
-- en el paso 4. Depende del día en que se aplique (mira qué cuotas ya se
-- emitieron). Para contarlo antes, en solo lectura:
--   bash scripts/perfil.sh uso-real ./node_modules/.bin/tsx scripts/contar-aumentos-por-avisar.ts
-- (guion de `gymflow-backend`).

-- 1. Desde qué día rige el cambio. NULL = anterior a este bloque: rigió al guardarse.
ALTER TABLE "plan_price_changes" ADD COLUMN "appliesFrom" DATE;
ALTER TABLE "membership_price_changes" ADD COLUMN "appliesFrom" DATE;
-- 2. La previsión del primer cobro al precio nuevo de cada socio (lo que dicen la pantalla y el aviso).
ALTER TABLE "membership_price_changes" ADD COLUMN "firstChargeOn" DATE;

-- 3. Cuándo llegó de verdad un aumento a una membresía: la cuota que ya lo
-- lleva. Solo se agrega; así `membership_price_changes` sigue sin editarse.
CREATE TABLE "membership_price_applications" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "membershipPriceChangeId" UUID NOT NULL,
  "membershipId" UUID NOT NULL,
  -- La cuota emitida con el precio nuevo (sin llave: la cuota nunca se borra).
  "chargeId" UUID,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "membership_price_applications_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "membership_price_applications_cambio_key" ON "membership_price_applications"("membershipPriceChangeId");
CREATE INDEX "membership_price_applications_org_membership_idx" ON "membership_price_applications"("organizationId", "membershipId");
ALTER TABLE "membership_price_applications" ADD CONSTRAINT "membership_price_applications_cambio_fkey" FOREIGN KEY ("membershipPriceChangeId") REFERENCES "membership_price_changes"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "membership_price_applications" ADD CONSTRAINT "membership_price_applications_membership_fkey" FOREIGN KEY ("membershipId") REFERENCES "memberships"("id") ON DELETE CASCADE ON UPDATE CASCADE;
GRANT SELECT, INSERT ON "membership_price_applications" TO gymflow_app;
REVOKE UPDATE, DELETE ON "membership_price_applications" FROM gymflow_app;

-- 4. LOS AUMENTOS YA GUARDADOS QUE AÚN NO LLEGAN A SU PRIMER COBRO (lo más
-- conservador: lo ya anunciado no cambia, salvo que dejara menos de 15 días).
-- Toca una fila de `membership_price_changes` solo si:
--   · es un aumento (`toPriceCents` > `fromPriceCents`);
--   · su membresía sigue viva y en el mismo plan del cambio;
--   · desde el cambio no se le ha emitido ninguna cuota de periodo (todavía no
--     paga el precio nuevo);
--   · y su siguiente cuota (`currentPeriodEnd`) cae ANTES de 15 días contados
--     desde el día del cambio en la zona del gimnasio (el plazo anunciado,
--     «a partir de tu siguiente pago», era menor al mínimo).
-- A esas filas les pone `appliesFrom` = día del cambio + 15, y a su membresía
-- le regresa el precio pactado a lo que pagaba antes del aumento (sin pactado:
-- el de lista de hoy menos esos aumentos). El aumento llega entonces en la
-- primera cuota que empiece y se emita desde ese día. Las demás filas no
-- cambian (rigieron al guardarse, `appliesFrom` NULL). Correrla dos veces no
-- hace nada más: la segunda vez esas filas ya tienen `appliesFrom`.
CREATE TEMP TABLE "_aumentos_por_avisar" AS
SELECT pc."id", pc."membershipId", (pc."toPriceCents" - pc."fromPriceCents") AS "delta",
       ((pc."createdAt" AT TIME ZONE COALESCE(o."timezone", 'America/Mexico_City'))::date + 15) AS "rige"
  FROM "membership_price_changes" pc
  JOIN "plan_price_changes" a ON a."id" = pc."planPriceChangeId"
  JOIN "memberships" ms ON ms."id" = pc."membershipId"
  JOIN "organizations" o ON o."id" = pc."organizationId"
 WHERE pc."appliesFrom" IS NULL
   AND pc."toPriceCents" > pc."fromPriceCents"
   AND ms."status" NOT IN ('CANCELED', 'EXPIRED')
   AND ms."planId" = a."planId"
   AND NOT EXISTS (SELECT 1 FROM "charges" c
                    WHERE c."membershipId" = pc."membershipId" AND c."organizationId" = pc."organizationId"
                      AND c."chargeType" = 'MEMBERSHIP_PERIOD' AND c."createdAt" > pc."createdAt")
   AND ms."currentPeriodEnd" < ((pc."createdAt" AT TIME ZONE COALESCE(o."timezone", 'America/Mexico_City'))::date + 15);

UPDATE "memberships" ms
   SET "agreedPriceCents" = GREATEST(0, COALESCE(ms."agreedPriceCents", p."priceCents") - x."suma")
  FROM (SELECT "membershipId", SUM("delta") AS "suma" FROM "_aumentos_por_avisar" GROUP BY 1) x,
       "plans" p
 WHERE ms."id" = x."membershipId" AND p."id" = ms."planId";

UPDATE "membership_price_changes" pc
   SET "appliesFrom" = x."rige"
  FROM "_aumentos_por_avisar" x
 WHERE pc."id" = x."id";

-- El acto también dice desde cuándo rige, si alguna de sus filas espera.
UPDATE "plan_price_changes" a
   SET "appliesFrom" = (SELECT MAX(pc."appliesFrom") FROM "membership_price_changes" pc WHERE pc."planPriceChangeId" = a."id")
 WHERE a."appliesFrom" IS NULL
   AND EXISTS (SELECT 1 FROM "membership_price_changes" pc WHERE pc."planPriceChangeId" = a."id" AND pc."appliesFrom" IS NOT NULL);

DROP TABLE "_aumentos_por_avisar";
