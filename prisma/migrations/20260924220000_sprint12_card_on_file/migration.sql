-- CreateEnum
CREATE TYPE "PaymentMethodStatus" AS ENUM ('ACTIVE', 'EXPIRED', 'REVOKED');

-- CreateEnum
CREATE TYPE "PaymentAttemptOutcome" AS ENUM ('SUCCESS', 'SOFT_DECLINE', 'HARD_DECLINE', 'AUTH_REQUIRED', 'ERROR', 'UNKNOWN');

-- CreateEnum
CREATE TYPE "RefundStatus" AS ENUM ('PENDING', 'SUCCEEDED', 'FAILED');

-- CreateEnum
CREATE TYPE "ChargebackStatus" AS ENUM ('OPEN', 'UNDER_REVIEW', 'WON', 'LOST', 'ACCEPTED');

-- CreateEnum
CREATE TYPE "WebhookEventStatus" AS ENUM ('RECEIVED', 'PROCESSED', 'IGNORED', 'FAILED', 'DEAD_LETTER');

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "paymentMethodId" UUID;

-- CreateTable
CREATE TABLE "payment_methods" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "provider" TEXT NOT NULL,
    "providerTokenRef" TEXT NOT NULL,
    "providerCustomerId" TEXT,
    "brand" TEXT,
    "last4" CHAR(4),
    "expMonth" SMALLINT,
    "expYear" SMALLINT,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "consentId" UUID,
    "status" "PaymentMethodStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMPTZ(3),
    "revokedReason" TEXT,

    CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_attempts" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "paymentId" UUID,
    "chargeId" UUID,
    "attemptNumber" SMALLINT NOT NULL,
    "idempotencyKey" TEXT NOT NULL,
    "outcome" "PaymentAttemptOutcome",
    "providerCode" TEXT,
    "providerMessage" TEXT,
    "rawResponse" JSONB,
    "attemptedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMPTZ(3),

    CONSTRAINT "payment_attempts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refunds" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "paymentId" UUID NOT NULL,
    "branchId" UUID,
    "amountCents" BIGINT NOT NULL,
    "status" "RefundStatus" NOT NULL DEFAULT 'PENDING',
    "reason" TEXT NOT NULL,
    "createdByUserId" UUID,
    "approvedByUserId" UUID,
    "externalReference" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "confirmedAt" TIMESTAMPTZ(3),

    CONSTRAINT "refunds_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chargebacks" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "paymentId" UUID NOT NULL,
    "amountCents" BIGINT NOT NULL,
    "status" "ChargebackStatus" NOT NULL DEFAULT 'OPEN',
    "providerCaseId" TEXT,
    "reasonCode" TEXT,
    "openedAt" TIMESTAMPTZ(3) NOT NULL,
    "dueByAt" TIMESTAMPTZ(3),
    "resolvedAt" TIMESTAMPTZ(3),
    "evidenceObjectKey" TEXT,

    CONSTRAINT "chargebacks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "webhook_events" (
    "id" UUID NOT NULL,
    "organizationId" UUID,
    "provider" TEXT NOT NULL,
    "providerEventId" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "rawPayload" JSONB NOT NULL,
    "signatureStatus" TEXT NOT NULL,
    "status" "WebhookEventStatus" NOT NULL DEFAULT 'RECEIVED',
    "processAttempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "providerCreatedAt" TIMESTAMPTZ(3),
    "receivedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedAt" TIMESTAMPTZ(3),

    CONSTRAINT "webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "payment_methods_organizationId_memberId_status_idx" ON "payment_methods"("organizationId", "memberId", "status");

-- CreateIndex
CREATE INDEX "payment_methods_organizationId_expYear_expMonth_idx" ON "payment_methods"("organizationId", "expYear", "expMonth");

-- CreateIndex
CREATE UNIQUE INDEX "payment_methods_provider_providerTokenRef_key" ON "payment_methods"("provider", "providerTokenRef");

-- CreateIndex
CREATE UNIQUE INDEX "payment_attempts_idempotencyKey_key" ON "payment_attempts"("idempotencyKey");

-- CreateIndex
CREATE INDEX "payment_attempts_organizationId_memberId_attemptedAt_idx" ON "payment_attempts"("organizationId", "memberId", "attemptedAt" DESC);

-- CreateIndex
CREATE INDEX "payment_attempts_organizationId_outcome_attemptedAt_idx" ON "payment_attempts"("organizationId", "outcome", "attemptedAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "payment_attempts_chargeId_attemptNumber_key" ON "payment_attempts"("chargeId", "attemptNumber");

-- CreateIndex
CREATE INDEX "refunds_organizationId_status_createdAt_idx" ON "refunds"("organizationId", "status", "createdAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "refunds_organizationId_idempotencyKey_key" ON "refunds"("organizationId", "idempotencyKey");

-- CreateIndex
CREATE UNIQUE INDEX "chargebacks_providerCaseId_key" ON "chargebacks"("providerCaseId");

-- CreateIndex
CREATE INDEX "chargebacks_organizationId_status_openedAt_idx" ON "chargebacks"("organizationId", "status", "openedAt" DESC);

-- CreateIndex
CREATE INDEX "webhook_events_status_receivedAt_idx" ON "webhook_events"("status", "receivedAt");

-- CreateIndex
CREATE UNIQUE INDEX "webhook_events_provider_providerEventId_key" ON "webhook_events"("provider", "providerEventId");

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_paymentMethodId_fkey" FOREIGN KEY ("paymentMethodId") REFERENCES "payment_methods"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_methods" ADD CONSTRAINT "payment_methods_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_methods" ADD CONSTRAINT "payment_methods_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_methods" ADD CONSTRAINT "payment_methods_consentId_fkey" FOREIGN KEY ("consentId") REFERENCES "member_consents"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_attempts" ADD CONSTRAINT "attempts_payment_same_org_fk" FOREIGN KEY ("paymentId", "organizationId") REFERENCES "payments"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_payment_same_org_fk" FOREIGN KEY ("paymentId", "organizationId") REFERENCES "payments"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chargebacks" ADD CONSTRAINT "chargebacks_payment_same_org_fk" FOREIGN KEY ("paymentId", "organizationId") REFERENCES "payments"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "webhook_events" ADD CONSTRAINT "webhook_events_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ── Índices parciales ──────────────────────────────────────────────────────

-- UN solo método predeterminado vivo por socio. Dos significa que nadie sabe
-- con cuál se va a cobrar el día 1, y eso se descubre cobrando dos veces.
CREATE UNIQUE INDEX "payment_methods_one_default_idx"
  ON "payment_methods" ("organizationId", "memberId")
  WHERE "isDefault" = true AND "status" = 'ACTIVE';

-- ── Invariantes ────────────────────────────────────────────────────────────

ALTER TABLE "payment_methods"
  ADD CONSTRAINT "payment_methods_last4_check"
  CHECK ("last4" IS NULL OR "last4" ~ '^[0-9]{4}$');

-- Lo que impide guardar un PAN en el campo de los últimos cuatro por error de
-- captura o de integración. Cuatro dígitos, ni uno más.
ALTER TABLE "payment_methods"
  ADD CONSTRAINT "payment_methods_revoked_check"
  CHECK (("status" = 'REVOKED') = ("revokedAt" IS NOT NULL));

ALTER TABLE "payment_methods"
  ADD CONSTRAINT "payment_methods_expiry_check"
  CHECK (("expMonth" IS NULL) = ("expYear" IS NULL)
     AND ("expMonth" IS NULL OR ("expMonth" BETWEEN 1 AND 12 AND "expYear" BETWEEN 2000 AND 2099)));

ALTER TABLE "payment_attempts"
  ADD CONSTRAINT "payment_attempts_number_check"
  CHECK ("attemptNumber" >= 1);

ALTER TABLE "refunds"
  ADD CONSTRAINT "refunds_amount_check"
  CHECK ("amountCents" > 0);

ALTER TABLE "refunds"
  ADD CONSTRAINT "refunds_reason_check"
  CHECK (btrim("reason") <> '');

ALTER TABLE "chargebacks"
  ADD CONSTRAINT "chargebacks_amount_check"
  CHECK ("amountCents" > 0);

ALTER TABLE "webhook_events"
  ADD CONSTRAINT "webhook_events_signature_check"
  CHECK ("signatureStatus" IN ('VALID', 'INVALID'));

-- ── No se reembolsa más de lo cobrado ──────────────────────────────────────
-- El servicio ya lo comprueba. Esto es lo que lo hace cierto también cuando
-- dos reembolsos parciales entran a la vez y los dos leen el mismo total
-- antes de que ninguno escriba.
CREATE OR REPLACE FUNCTION refund_within_payment() RETURNS trigger AS $$
DECLARE
  total_pago   BIGINT;
  total_reemb  BIGINT;
BEGIN
  SELECT "amountCents" INTO total_pago FROM "payments" WHERE "id" = NEW."paymentId" FOR UPDATE;

  SELECT COALESCE(SUM("amountCents"), 0) INTO total_reemb
    FROM "refunds"
   WHERE "paymentId" = NEW."paymentId"
     AND "status" <> 'FAILED'
     AND "id" <> NEW."id";

  IF total_reemb + NEW."amountCents" > total_pago THEN
    RAISE EXCEPTION 'refunds: % excede lo cobrado (pago %, ya reembolsado %)',
      NEW."amountCents", total_pago, total_reemb;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER refund_within_payment_trg
  BEFORE INSERT OR UPDATE ON "refunds"
  FOR EACH ROW EXECUTE FUNCTION refund_within_payment();

-- ── El resultado de un intento se escribe UNA vez ──────────────────────────
-- Salvo desde UNKNOWN, que es precisamente "todavía no se sabe": es el único
-- estado del que se puede salir, y solo reconsultando al procesador.
--
-- Sin esto, cualquiera podría marcar como fallido un cobro que sí ocurrió, y
-- el reintento lo cobraría por segunda vez.
CREATE OR REPLACE FUNCTION payment_attempt_resolve_once() RETURNS trigger AS $$
BEGIN
  IF OLD."outcome" IS NOT NULL AND OLD."outcome" <> 'UNKNOWN'
     AND NEW."outcome" IS DISTINCT FROM OLD."outcome" THEN
    RAISE EXCEPTION 'payment_attempts: el resultado % ya está escrito y no se reescribe', OLD."outcome";
  END IF;
  IF NEW."idempotencyKey" IS DISTINCT FROM OLD."idempotencyKey"
     OR NEW."attemptNumber" IS DISTINCT FROM OLD."attemptNumber" THEN
    RAISE EXCEPTION 'payment_attempts: la clave de idempotencia es inmutable';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payment_attempt_resolve_once_trg
  BEFORE UPDATE ON "payment_attempts"
  FOR EACH ROW EXECUTE FUNCTION payment_attempt_resolve_once();

-- ── Privilegios ────────────────────────────────────────────────────────────
-- RECORDATORIO: un `GRANT ... ON ALL TABLES` DESHACE los REVOKE anteriores.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO gymflow_app;

REVOKE UPDATE, DELETE ON "audit_logs" FROM gymflow_app;
REVOKE DELETE ON "member_consents" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "visit_ledger_entries" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "membership_events" FROM gymflow_app;
REVOKE DELETE ON "payments" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "payment_allocations" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "charge_adjustments" FROM gymflow_app;
REVOKE DELETE ON "charges" FROM gymflow_app;
REVOKE DELETE ON "billing_cycles" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "cash_movements" FROM gymflow_app;
REVOKE DELETE ON "cash_sessions" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "inventory_movements" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "pos_sale_lines" FROM gymflow_app;
REVOKE DELETE ON "pos_sales" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "access_decisions" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "attendance_events" FROM gymflow_app;
REVOKE DELETE ON "member_credentials" FROM gymflow_app;
REVOKE DELETE ON "consent_documents" FROM gymflow_app;
REVOKE DELETE ON "member_intakes" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "class_booking_blocks" FROM gymflow_app;
-- Nuevas del Sprint 12. El intento es la prueba de qué se le pidió al
-- procesador y cuándo; el evento crudo es lo que permite reconstruir el
-- pasado. Ninguno de los dos se borra desde la aplicación.
--
-- El intento SÍ admite UPDATE, y tiene que admitirlo: la fila se escribe
-- antes de llamar y se completa con la respuesta. Lo que impide reescribir
-- el pasado no es el permiso, es el trigger de abajo.
REVOKE DELETE ON "payment_attempts" FROM gymflow_app;
REVOKE DELETE ON "refunds" FROM gymflow_app;
REVOKE DELETE ON "chargebacks" FROM gymflow_app;
REVOKE DELETE ON "webhook_events" FROM gymflow_app;
