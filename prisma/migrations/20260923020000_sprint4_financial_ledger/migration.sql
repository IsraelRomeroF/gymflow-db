-- CreateEnum
CREATE TYPE "ChargeType" AS ENUM ('MEMBERSHIP_PERIOD', 'SIGNUP_FEE', 'VISIT_PACK', 'DAY_PASS', 'CLASS_SINGLE', 'NO_SHOW_PENALTY', 'POS_SALE', 'PRORATION_ADJUSTMENT', 'OPENING_BALANCE', 'MANUAL_ADJUSTMENT');

-- CreateEnum
CREATE TYPE "ChargeStatus" AS ENUM ('DRAFT', 'OPEN', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'VOID', 'WRITTEN_OFF');

-- CreateEnum
CREATE TYPE "PaymentMethodType" AS ENUM ('CASH', 'CARD_TERMINAL', 'CARD_ON_FILE', 'SPEI_TRANSFER', 'OXXO_REF', 'CREDIT_NOTE');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('INITIATED', 'PROCESSING', 'REQUIRES_ACTION', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELED', 'REVERSED');

-- CreateEnum
CREATE TYPE "AdjustmentType" AS ENUM ('DISCOUNT', 'WAIVER', 'LATE_FEE', 'CORRECTION');

-- CreateEnum
CREATE TYPE "BillingCycleStatus" AS ENUM ('RUNNING', 'COMPLETED', 'FAILED');

-- CreateTable
CREATE TABLE "billing_cycles" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "runDate" DATE NOT NULL,
    "status" "BillingCycleStatus" NOT NULL DEFAULT 'RUNNING',
    "chargesCreated" INTEGER NOT NULL DEFAULT 0,
    "chargesSkipped" INTEGER NOT NULL DEFAULT 0,
    "amountCents" BIGINT NOT NULL DEFAULT 0,
    "startedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" TIMESTAMPTZ(3),
    "error" TEXT,

    CONSTRAINT "billing_cycles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "charges" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "membershipId" UUID,
    "branchId" UUID,
    "billingCycleId" UUID,
    "chargeType" "ChargeType" NOT NULL,
    "status" "ChargeStatus" NOT NULL DEFAULT 'OPEN',
    "concept" TEXT NOT NULL,
    "subtotalCents" BIGINT NOT NULL,
    "taxCents" BIGINT NOT NULL DEFAULT 0,
    "discountCents" BIGINT NOT NULL DEFAULT 0,
    "amountCents" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'MXN',
    "allocatedCents" BIGINT NOT NULL DEFAULT 0,
    "adjustedCents" BIGINT NOT NULL DEFAULT 0,
    "periodStart" DATE,
    "periodEnd" DATE,
    "issuedAt" TIMESTAMPTZ(3),
    "dueDate" DATE NOT NULL,
    "idempotencyKey" TEXT,
    "voidedAt" TIMESTAMPTZ(3),
    "voidReason" TEXT,
    "writtenOffAt" TIMESTAMPTZ(3),
    "writeOffReason" TEXT,
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "charges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "charge_adjustments" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "chargeId" UUID NOT NULL,
    "adjustmentType" "AdjustmentType" NOT NULL,
    "amountCents" BIGINT NOT NULL,
    "reason" TEXT NOT NULL,
    "approvedByUserId" UUID,
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "charge_adjustments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "branchId" UUID,
    "method" "PaymentMethodType" NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'INITIATED',
    "amountCents" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'MXN',
    "unappliedCents" BIGINT NOT NULL DEFAULT 0,
    "idempotencyKey" TEXT,
    "externalRef" TEXT,
    "processorName" TEXT,
    "receivedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,
    "reversesPaymentId" UUID,
    "reversalReason" TEXT,
    "failureCode" TEXT,
    "failureReason" TEXT,
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_allocations" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "paymentId" UUID NOT NULL,
    "chargeId" UUID NOT NULL,
    "amountCents" BIGINT NOT NULL,
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_allocations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "billing_cycles_organizationId_runDate_idx" ON "billing_cycles"("organizationId", "runDate" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "billing_cycles_id_org_key" ON "billing_cycles"("id", "organizationId");

-- CreateIndex
CREATE INDEX "charges_organizationId_memberId_dueDate_idx" ON "charges"("organizationId", "memberId", "dueDate" DESC);

-- CreateIndex
CREATE INDEX "charges_organizationId_status_dueDate_idx" ON "charges"("organizationId", "status", "dueDate");

-- CreateIndex
CREATE INDEX "charges_organizationId_branchId_createdAt_idx" ON "charges"("organizationId", "branchId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "charges_membershipId_periodStart_idx" ON "charges"("membershipId", "periodStart");

-- CreateIndex
CREATE UNIQUE INDEX "charges_id_org_key" ON "charges"("id", "organizationId");

-- CreateIndex
CREATE INDEX "charge_adjustments_organizationId_chargeId_idx" ON "charge_adjustments"("organizationId", "chargeId");

-- CreateIndex
CREATE UNIQUE INDEX "payments_reversesPaymentId_key" ON "payments"("reversesPaymentId");

-- CreateIndex
CREATE INDEX "payments_organizationId_memberId_receivedAt_idx" ON "payments"("organizationId", "memberId", "receivedAt" DESC);

-- CreateIndex
CREATE INDEX "payments_organizationId_branchId_businessDate_idx" ON "payments"("organizationId", "branchId", "businessDate");

-- CreateIndex
CREATE INDEX "payments_organizationId_status_receivedAt_idx" ON "payments"("organizationId", "status", "receivedAt");

-- CreateIndex
CREATE UNIQUE INDEX "payments_id_org_key" ON "payments"("id", "organizationId");

-- CreateIndex
CREATE INDEX "payment_allocations_organizationId_chargeId_idx" ON "payment_allocations"("organizationId", "chargeId");

-- CreateIndex
CREATE UNIQUE INDEX "alloc_payment_charge_key" ON "payment_allocations"("paymentId", "chargeId");

-- AddForeignKey
ALTER TABLE "billing_cycles" ADD CONSTRAINT "billing_cycles_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "charges" ADD CONSTRAINT "charges_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "charges" ADD CONSTRAINT "charges_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "charges" ADD CONSTRAINT "charges_membership_same_org_fk" FOREIGN KEY ("membershipId", "organizationId") REFERENCES "memberships"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "charges" ADD CONSTRAINT "charges_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "charges" ADD CONSTRAINT "charges_cycle_same_org_fk" FOREIGN KEY ("billingCycleId", "organizationId") REFERENCES "billing_cycles"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "charge_adjustments" ADD CONSTRAINT "adjustments_charge_same_org_fk" FOREIGN KEY ("chargeId", "organizationId") REFERENCES "charges"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_reversesPaymentId_fkey" FOREIGN KEY ("reversesPaymentId") REFERENCES "payments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_allocations" ADD CONSTRAINT "alloc_payment_same_org_fk" FOREIGN KEY ("paymentId", "organizationId") REFERENCES "payments"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_allocations" ADD CONSTRAINT "alloc_charge_same_org_fk" FOREIGN KEY ("chargeId", "organizationId") REFERENCES "charges"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ════════════════════════════════════════════════════════════════════════════
-- GARANTÍAS QUE PRISMA NO PUEDE EXPRESAR
--
-- Aquí vive SOLO lo que el esquema declarativo no alcanza: índices parciales,
-- CHECKs, triggers y privilegios. Todo lo demás (únicos compuestos, FKs
-- compuestas, índices normales y GIN) vive en schema.prisma, porque si se
-- pone aquí Prisma lo trata como deriva y lo borra en la siguiente migración.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Idempotencia: la barrera real contra el cargo duplicado ────────────────
-- Sin esto, la "idempotencia" sería una consulta previa, y dos ejecuciones
-- simultáneas del job pasarían ambas por la rendija entre el SELECT y el
-- INSERT. El índice único lo resuelve en el motor, no en la aplicación.
CREATE UNIQUE INDEX "charges_org_idempotency_key"
  ON "charges" ("organizationId", "idempotencyKey")
  WHERE "idempotencyKey" IS NOT NULL;

CREATE UNIQUE INDEX "payments_org_idempotency_key"
  ON "payments" ("organizationId", "idempotencyKey")
  WHERE "idempotencyKey" IS NOT NULL;

-- Una sola corrida VÁLIDA de facturación por día y organización. Una corrida
-- fallida no bloquea el reintento.
CREATE UNIQUE INDEX "billing_cycles_one_valid_per_day"
  ON "billing_cycles" ("organizationId", "runDate")
  WHERE "status" <> 'FAILED';

-- ── Aritmética del cargo ───────────────────────────────────────────────────
ALTER TABLE "charges"
  ADD CONSTRAINT "charges_amount_composition_check"
  CHECK ("amountCents" = "subtotalCents" + "taxCents" - "discountCents");

ALTER TABLE "charges"
  ADD CONSTRAINT "charges_non_negative_check"
  CHECK ("subtotalCents" >= 0 AND "taxCents" >= 0 AND "discountCents" >= 0
     AND "amountCents" >= 0 AND "allocatedCents" >= 0 AND "adjustedCents" >= 0);

-- LA invariante del libro: no se puede cobrar de más contra un cargo.
-- El excedente TIENE que quedar como saldo a favor del socio; un cargo
-- negativo no existe en contabilidad y corrompería todo reporte de cartera.
ALTER TABLE "charges"
  ADD CONSTRAINT "charges_no_overpayment_check"
  CHECK ("allocatedCents" + "adjustedCents" <= "amountCents");

-- Periodo semiabierto [inicio, fin), igual que la membresía.
ALTER TABLE "charges"
  ADD CONSTRAINT "charges_period_order_check"
  CHECK ("periodStart" IS NULL OR "periodEnd" IS NULL OR "periodEnd" > "periodStart");

-- Una cuota de periodo SIN membresía sería un cargo huérfano imposible de
-- conciliar contra el contrato que lo originó.
ALTER TABLE "charges"
  ADD CONSTRAINT "charges_membership_required_check"
  CHECK ("chargeType" <> 'MEMBERSHIP_PERIOD' OR "membershipId" IS NOT NULL);

ALTER TABLE "charges"
  ADD CONSTRAINT "charges_void_reason_check"
  CHECK (("voidedAt" IS NULL) = ("voidReason" IS NULL));

ALTER TABLE "charges"
  ADD CONSTRAINT "charges_writeoff_reason_check"
  CHECK (("writtenOffAt" IS NULL) = ("writeOffReason" IS NULL));

-- ── Aritmética del pago ────────────────────────────────────────────────────
ALTER TABLE "payments"
  ADD CONSTRAINT "payments_amount_not_zero_check"
  CHECK ("amountCents" <> 0);

-- Un importe negativo es, por definición, un contra-asiento. Y todo
-- contra-asiento es negativo. La equivalencia va en ambos sentidos a
-- propósito: impide tanto el "reverso" positivo como el negativo suelto.
ALTER TABLE "payments"
  ADD CONSTRAINT "payments_negative_only_if_reversal_check"
  CHECK (("amountCents" < 0) = ("reversesPaymentId" IS NOT NULL));

ALTER TABLE "payments"
  ADD CONSTRAINT "payments_unapplied_range_check"
  CHECK ("unappliedCents" >= 0 AND "unappliedCents" <= abs("amountCents"));

ALTER TABLE "payments"
  ADD CONSTRAINT "payments_reversal_reason_check"
  CHECK ("reversesPaymentId" IS NULL OR "reversalReason" IS NOT NULL);

-- Un pago no puede revertirse a sí mismo.
ALTER TABLE "payments"
  ADD CONSTRAINT "payments_no_self_reversal_check"
  CHECK ("reversesPaymentId" IS NULL OR "reversesPaymentId" <> "id");

-- ── Asignaciones y ajustes ─────────────────────────────────────────────────
ALTER TABLE "payment_allocations"
  ADD CONSTRAINT "alloc_amount_not_zero_check"
  CHECK ("amountCents" <> 0);

ALTER TABLE "charge_adjustments"
  ADD CONSTRAINT "adjustments_amount_not_zero_check"
  CHECK ("amountCents" <> 0);

-- Coherencia entre el tipo de ajuste y su signo: un "descuento" que aumenta
-- la deuda es un error de captura, no una decisión.
ALTER TABLE "charge_adjustments"
  ADD CONSTRAINT "adjustments_sign_coherence_check"
  CHECK (
    ("adjustmentType" IN ('DISCOUNT', 'WAIVER') AND "amountCents" > 0)
    OR ("adjustmentType" = 'LATE_FEE' AND "amountCents" < 0)
    OR ("adjustmentType" = 'CORRECTION')
  );

-- Condonar exige motivo real, no un espacio en blanco.
ALTER TABLE "charge_adjustments"
  ADD CONSTRAINT "adjustments_reason_not_blank_check"
  CHECK (length(btrim("reason")) >= 3);

-- ── Append-only, defensa en profundidad ────────────────────────────────────
-- Los REVOKE de abajo ya lo impiden para gymflow_app, pero el trigger protege
-- también contra una conexión con el rol dueño: el vector clásico del robo
-- hormiga es borrar el pago en efectivo después de cobrarlo.
CREATE OR REPLACE FUNCTION reject_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'La tabla % es append-only: %s no está permitido',
    TG_TABLE_NAME, TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payment_allocations_append_only
  BEFORE DELETE ON "payment_allocations"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER charge_adjustments_append_only
  BEFORE UPDATE OR DELETE ON "charge_adjustments"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER payments_no_delete
  BEFORE DELETE ON "payments"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

-- ── Privilegios ────────────────────────────────────────────────────────────
-- RECORDATORIO (ya nos mordió una vez): un `GRANT ... ON ALL TABLES` DESHACE
-- los REVOKE anteriores. Por eso se reaplican TODOS, incluidos los de los
-- sprints previos, cada vez.
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
