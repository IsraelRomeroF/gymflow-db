-- PLATAFORMA · COBRANZA CON AVISOS Y CAMBIOS CON VIGENCIA (auditoría 8, fase 3,
-- bloque 3.11; decisiones D-37 y D-38). Aditiva y repetible en lo que toca a
-- datos: no cambia ninguna factura, ningún pago ni el servicio de ninguna marca.

-- ── D-37 · Avisos al dueño del gimnasio ─────────────────────────────────────
-- Un aviso que GymFlow le debe al dueño de una marca: factura emitida, factura
-- vencida, servicio suspendido, cambio de precio anunciado. El texto se congela
-- al nacer. `deliveredOn` es el primer día con CONSTANCIA de que le llegó: una
-- notificación entregada a su teléfono, el dueño lo vio en su panel, o una
-- persona de GymFlow se lo mandó. La suspensión automática cuenta sus días
-- desde ahí: sin constancia, no hay suspensión.
CREATE TABLE "platform_notices" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "kind" TEXT NOT NULL,
  "dedupeKey" TEXT NOT NULL,
  "invoiceId" UUID,
  "priceChangeId" UUID,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "noticeOn" DATE NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "pushedAt" TIMESTAMPTZ(3),
  "pushDevices" INTEGER NOT NULL DEFAULT 0,
  "seenAt" TIMESTAMPTZ(3),
  "seenByUserId" UUID,
  "sentAt" TIMESTAMPTZ(3),
  "sentByUserId" UUID,
  "deliveredOn" DATE,
  "closedAt" TIMESTAMPTZ(3),
  "closeReason" TEXT,
  CONSTRAINT "platform_notices_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "platform_notices_kind_chk" CHECK ("kind" IN ('INVOICE_ISSUED', 'INVOICE_OVERDUE', 'SERVICE_SUSPENDED', 'PRICE_CHANGE', 'PRICE_CHANGE_CANCELED')),
  -- Entregado = hay constancia por alguna vía; nunca una fecha sin su vía ni al revés.
  CONSTRAINT "platform_notices_entrega_chk" CHECK (("deliveredOn" IS NULL) = ("pushedAt" IS NULL AND "seenAt" IS NULL AND "sentAt" IS NULL)),
  CONSTRAINT "platform_notices_cierre_chk" CHECK (("closedAt" IS NULL) = ("closeReason" IS NULL))
);
CREATE UNIQUE INDEX "platform_notices_dedupe_key" ON "platform_notices"("dedupeKey");
CREATE INDEX "platform_notices_org_idx" ON "platform_notices"("organizationId", "closedAt", "createdAt");
CREATE INDEX "platform_notices_invoice_idx" ON "platform_notices"("invoiceId");
ALTER TABLE "platform_notices" ADD CONSTRAINT "platform_notices_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "platform_notices" ADD CONSTRAINT "platform_notices_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "platform_invoices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE ON "platform_notices" TO gymflow_app;
-- Un aviso es la constancia de que se avisó antes de suspender: no se borra.
REVOKE DELETE ON "platform_notices" FROM gymflow_app;

-- Prórroga: la suspensión automática no toca a la marca hasta ese día (incluido).
ALTER TABLE "organizations" ADD COLUMN "autoSuspendHoldUntil" DATE;
-- La suspensión vigente la hizo el sistema por falta de pago (no una persona).
ALTER TABLE "organizations" ADD COLUMN "suspendedAutomatically" BOOLEAN NOT NULL DEFAULT false;

-- ── D-38 · Cambios de precio o de plan con fecha avisada ────────────────────
-- Un cambio anunciado: lo que costaba (o incluía) y lo que costará desde el
-- primer día de un mes. Hasta ese día cada marca conserva lo que tenía.
CREATE TABLE "platform_price_changes" (
  "id" UUID NOT NULL,
  "kind" TEXT NOT NULL,
  "moduleKey" TEXT,
  "planId" UUID,
  "before" JSONB NOT NULL,
  "after" JSONB NOT NULL,
  "effectiveFrom" DATE NOT NULL,
  "announcedOn" DATE NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdByUserId" UUID,
  "appliedAt" TIMESTAMPTZ(3),
  "canceledAt" TIMESTAMPTZ(3),
  "canceledByUserId" UUID,
  "cancelReason" TEXT,
  CONSTRAINT "platform_price_changes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "platform_price_changes_kind_chk" CHECK (("kind" = 'PRICE' AND "moduleKey" IS NOT NULL AND "planId" IS NULL) OR ("kind" = 'PLAN' AND "planId" IS NOT NULL AND "moduleKey" IS NULL)),
  -- Aplica desde una factura: siempre el día 1 de un mes, y después de anunciarse.
  CONSTRAINT "platform_price_changes_dia_uno_chk" CHECK (EXTRACT(DAY FROM "effectiveFrom") = 1),
  CONSTRAINT "platform_price_changes_aviso_chk" CHECK ("effectiveFrom" > "announcedOn"),
  CONSTRAINT "platform_price_changes_estado_chk" CHECK ("appliedAt" IS NULL OR "canceledAt" IS NULL),
  CONSTRAINT "platform_price_changes_cancel_chk" CHECK (("canceledAt" IS NULL) = ("cancelReason" IS NULL))
);
-- Un solo cambio pendiente por precio y por plan: el siguiente se anuncia cuando este aplica o se cancela.
CREATE UNIQUE INDEX "platform_price_changes_pendiente_precio_key" ON "platform_price_changes"("moduleKey") WHERE "kind" = 'PRICE' AND "appliedAt" IS NULL AND "canceledAt" IS NULL;
CREATE UNIQUE INDEX "platform_price_changes_pendiente_plan_key" ON "platform_price_changes"("planId") WHERE "kind" = 'PLAN' AND "appliedAt" IS NULL AND "canceledAt" IS NULL;
CREATE INDEX "platform_price_changes_effective_idx" ON "platform_price_changes"("effectiveFrom");
ALTER TABLE "platform_price_changes" ADD CONSTRAINT "platform_price_changes_planId_fkey" FOREIGN KEY ("planId") REFERENCES "platform_plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE ON "platform_price_changes" TO gymflow_app;
-- La historia de precios sirve para facturar un mes pasado con lo que valía: no se borra.
REVOKE DELETE ON "platform_price_changes" FROM gymflow_app;

-- La versión del plan que cada marca tiene: { planId, name, monthlyCents, modules, since }.
-- El cobro lee esta, no el catálogo vivo.
ALTER TABLE "organizations" ADD COLUMN "platformPlanSnapshot" JSONB;
-- Las marcas que ya tienen plan conservan exactamente lo que hoy pagan: su
-- versión es el plan como está hoy. Repetible: solo llena las que no la tienen.
UPDATE "organizations" o
   SET "platformPlanSnapshot" = jsonb_build_object(
         'planId', p."id", 'name', p."name",
         'monthlyCents', CASE WHEN p."monthlyCents" IS NULL THEN NULL ELSE p."monthlyCents"::text END,
         'modules', p."modules",
         'since', to_char((now() AT TIME ZONE 'America/Mexico_City')::date, 'YYYY-MM-DD'))
  FROM "platform_plans" p
 WHERE o."platformPlanId" = p."id" AND o."platformPlanSnapshot" IS NULL;
