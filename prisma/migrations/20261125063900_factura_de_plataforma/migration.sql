-- PLATAFORMA · LA FACTURA DE GYMFLOW A LOS GIMNASIOS (auditoría 8, fase 4,
-- bloque 4.9; decisión D-39): descuentos o precio especial por meses y con
-- motivo, primer mes y módulos a medio mes por días, IVA aparte y datos
-- fiscales. Aditiva: agrega dos tablas y columnas nuevas; NO escribe en
-- ninguna fila que ya exista (ninguna factura emitida cambia un centavo, y el
-- IVA nace apagado: sin filas en `platform_tax_changes` no se suma nada).

-- ── Descuento o precio especial de una marca, por meses y con motivo ────────
-- `kind`: PERCENT (porcentaje en puntos base: 2000 = 20 %), AMOUNT (importe
-- fijo al mes) o SPECIAL_PRICE (la mensualidad completa, sin IVA, cuesta ese
-- importe). Vale para las facturas de `months` meses desde `fromMonth` (día 1)
-- y caduca solo: no hay nada que apagar. No se edita: se cancela y se da otro.
CREATE TABLE "organization_billing_adjustments" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "kind" TEXT NOT NULL,
  "percentBps" INTEGER,
  "amountCents" BIGINT,
  "fromMonth" DATE NOT NULL,
  "months" INTEGER NOT NULL,
  "reason" TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdByUserId" UUID,
  "canceledAt" TIMESTAMPTZ(3),
  "canceledByUserId" UUID,
  "cancelReason" TEXT,
  CONSTRAINT "organization_billing_adjustments_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "organization_billing_adjustments_kind_chk" CHECK (
    ("kind" = 'PERCENT' AND "percentBps" BETWEEN 1 AND 10000 AND "amountCents" IS NULL)
    OR ("kind" IN ('AMOUNT', 'SPECIAL_PRICE') AND "amountCents" > 0 AND "percentBps" IS NULL)),
  CONSTRAINT "organization_billing_adjustments_dia_uno_chk" CHECK (EXTRACT(DAY FROM "fromMonth") = 1),
  CONSTRAINT "organization_billing_adjustments_meses_chk" CHECK ("months" BETWEEN 1 AND 24),
  CONSTRAINT "organization_billing_adjustments_motivo_chk" CHECK (length(btrim("reason")) >= 3),
  CONSTRAINT "organization_billing_adjustments_cancel_chk" CHECK (("canceledAt" IS NULL) = ("cancelReason" IS NULL))
);
CREATE INDEX "organization_billing_adjustments_org_idx" ON "organization_billing_adjustments"("organizationId", "fromMonth");
ALTER TABLE "organization_billing_adjustments" ADD CONSTRAINT "organization_billing_adjustments_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE ON "organization_billing_adjustments" TO gymflow_app;
-- Un descuento dado explica por qué una factura salió más baja: no se borra.
REVOKE DELETE ON "organization_billing_adjustments" FROM gymflow_app;

-- ── IVA de las facturas de GymFlow, con fecha de inicio ─────────────────────
-- Cada fila dice qué IVA llevan las facturas DESDE la de un mes (`effectiveFrom`,
-- día 1): la tasa en puntos base (1600 = 16 %; 0 = sin IVA) y si se SUMA a los
-- precios (`included` falso: el total sube) o si los precios ya lo incluyen
-- (`included` verdadero: el total no cambia, solo se desglosa). Sin filas no
-- hay IVA. Para un mes manda la fila viva más reciente que ya empezó.
CREATE TABLE "platform_tax_changes" (
  "id" UUID NOT NULL,
  "rateBps" INTEGER NOT NULL,
  "included" BOOLEAN NOT NULL DEFAULT false,
  "effectiveFrom" DATE NOT NULL,
  "announcedOn" DATE NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdByUserId" UUID,
  "canceledAt" TIMESTAMPTZ(3),
  "canceledByUserId" UUID,
  "cancelReason" TEXT,
  CONSTRAINT "platform_tax_changes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "platform_tax_changes_tasa_chk" CHECK ("rateBps" BETWEEN 0 AND 5000),
  CONSTRAINT "platform_tax_changes_dia_uno_chk" CHECK (EXTRACT(DAY FROM "effectiveFrom") = 1),
  CONSTRAINT "platform_tax_changes_cancel_chk" CHECK (("canceledAt" IS NULL) = ("cancelReason" IS NULL))
);
-- Un solo cambio vivo por fecha de inicio.
CREATE UNIQUE INDEX "platform_tax_changes_fecha_key" ON "platform_tax_changes"("effectiveFrom") WHERE "canceledAt" IS NULL;
GRANT SELECT, INSERT, UPDATE ON "platform_tax_changes" TO gymflow_app;
-- De aquí sale qué IVA llevaba la factura de un mes pasado: no se borra.
REVOKE DELETE ON "platform_tax_changes" FROM gymflow_app;

-- ── Lo que cada factura guarda de más al emitirse ───────────────────────────
-- `totalCents` sigue siendo LO QUE SE PAGA (cobranza, abonos y suspensión no
-- cambian). Las facturas ya emitidas quedan con `subtotalCents` NULL: se leen
-- como «total sin desglose de IVA», exactamente por lo que se emitieron.
ALTER TABLE "platform_invoices" ADD COLUMN "subtotalCents" BIGINT;
ALTER TABLE "platform_invoices" ADD COLUMN "taxCents" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "platform_invoices" ADD COLUMN "taxRateBps" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "platform_invoices" ADD COLUMN "taxIncluded" BOOLEAN NOT NULL DEFAULT false;
-- El descuento que llevó (también va como renglón en `lines`, en negativo).
ALTER TABLE "platform_invoices" ADD COLUMN "discountCents" BIGINT NOT NULL DEFAULT 0;
-- Los datos fiscales del gimnasio (razón social, RFC) y los de GymFlow como
-- emisor, tal como estaban el día en que se emitió.
ALTER TABLE "platform_invoices" ADD COLUMN "receiver" JSONB;
ALTER TABLE "platform_invoices" ADD COLUMN "issuer" JSONB;
ALTER TABLE "platform_invoices" ADD CONSTRAINT "platform_invoices_desglose_chk" CHECK ("taxCents" >= 0 AND "discountCents" >= 0 AND ("subtotalCents" IS NULL OR "subtotalCents" + "taxCents" = "totalCents"));

-- ── Desde qué día está contratado un módulo agregado después del alta ───────
-- NULL = desde que la marca empezó (así quedan todos los que ya existen: a
-- nadie se le cobra de más ni de menos por lo ya contratado). Se llena solo
-- al contratar un módulo que la marca no tenía.
ALTER TABLE "organization_entitlements" ADD COLUMN "contractedOn" DATE;
