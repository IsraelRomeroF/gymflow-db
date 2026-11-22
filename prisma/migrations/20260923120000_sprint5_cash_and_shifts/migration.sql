-- CreateEnum
CREATE TYPE "CashSessionStatus" AS ENUM ('OPEN', 'CLOSED', 'RECONCILED');

-- CreateEnum
CREATE TYPE "CashMovementType" AS ENUM ('FLOAT_IN', 'WITHDRAWAL', 'EXPENSE', 'DEPOSIT', 'CORRECTION');

-- AlterTable
ALTER TABLE "charge_adjustments" ADD COLUMN     "reasonCode" TEXT;

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "cashSessionId" UUID,
ADD COLUMN     "folio" TEXT;

-- CreateTable
CREATE TABLE "cash_registers" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "folioCounter" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "cash_registers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cash_sessions" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "cashRegisterId" UUID NOT NULL,
    "openedByUserId" UUID NOT NULL,
    "closedByUserId" UUID,
    "shiftLabel" TEXT,
    "businessDate" DATE NOT NULL,
    "status" "CashSessionStatus" NOT NULL DEFAULT 'OPEN',
    "openingFloatCents" BIGINT NOT NULL,
    "expectedCashCents" BIGINT,
    "countedCashCents" BIGINT,
    "varianceCents" BIGINT,
    "varianceReason" TEXT,
    "openedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closedAt" TIMESTAMPTZ(3),

    CONSTRAINT "cash_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cash_movements" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "cashSessionId" UUID NOT NULL,
    "movementType" "CashMovementType" NOT NULL,
    "amountCents" BIGINT NOT NULL,
    "reason" TEXT NOT NULL,
    "createdByUserId" UUID NOT NULL,
    "approvedByUserId" UUID,
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cash_movements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "cash_registers_organizationId_branchId_isActive_idx" ON "cash_registers"("organizationId", "branchId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "cash_registers_id_org_key" ON "cash_registers"("id", "organizationId");

-- CreateIndex
CREATE INDEX "cash_sessions_organizationId_branchId_businessDate_idx" ON "cash_sessions"("organizationId", "branchId", "businessDate");

-- CreateIndex
CREATE INDEX "cash_sessions_organizationId_status_openedAt_idx" ON "cash_sessions"("organizationId", "status", "openedAt");

-- CreateIndex
CREATE UNIQUE INDEX "cash_sessions_id_org_key" ON "cash_sessions"("id", "organizationId");

-- CreateIndex
CREATE INDEX "cash_movements_organizationId_cashSessionId_at_idx" ON "cash_movements"("organizationId", "cashSessionId", "at");

-- CreateIndex
CREATE INDEX "payments_cashSessionId_receivedAt_idx" ON "payments"("cashSessionId", "receivedAt");

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_session_same_org_fk" FOREIGN KEY ("cashSessionId", "organizationId") REFERENCES "cash_sessions"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_registers" ADD CONSTRAINT "registers_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_registers" ADD CONSTRAINT "cash_registers_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_sessions" ADD CONSTRAINT "sessions_register_same_org_fk" FOREIGN KEY ("cashRegisterId", "organizationId") REFERENCES "cash_registers"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_sessions" ADD CONSTRAINT "sessions_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_movements" ADD CONSTRAINT "movements_session_same_org_fk" FOREIGN KEY ("cashSessionId", "organizationId") REFERENCES "cash_sessions"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ════════════════════════════════════════════════════════════════════════════
-- GARANTÍAS QUE PRISMA NO PUEDE EXPRESAR
-- ════════════════════════════════════════════════════════════════════════════

-- ── Una sola sesión abierta POR CAJA ───────────────────────────────────────
-- Por caja, no por sucursal: si dos cajeros comparten una sede con dos cajas,
-- cada uno responde por la suya. Un faltante que no es de nadie no se
-- investiga, y deja de ser un control.
CREATE UNIQUE INDEX "cash_sessions_one_open_per_register"
  ON "cash_sessions" ("cashRegisterId")
  WHERE "status" = 'OPEN';

CREATE UNIQUE INDEX "cash_registers_branch_code_key"
  ON "cash_registers" ("branchId", "code")
  WHERE "deletedAt" IS NULL;

-- El folio es la referencia que el socio cita por teléfono: no puede repetirse.
CREATE UNIQUE INDEX "payments_org_folio_key"
  ON "payments" ("organizationId", "folio")
  WHERE "folio" IS NOT NULL;

-- ── Reglas del turno ───────────────────────────────────────────────────────
-- No hay cierre "ciego": cerrar exige haber contado.
ALTER TABLE "cash_sessions"
  ADD CONSTRAINT "sessions_closed_requires_count_check"
  CHECK ("status" = 'OPEN' OR "countedCashCents" IS NOT NULL);

-- Toda diferencia exige motivo. También el SOBRANTE: un sobrante sistemático
-- es la firma de un cobro no registrado que aún no ha salido del cajón.
ALTER TABLE "cash_sessions"
  ADD CONSTRAINT "sessions_variance_requires_reason_check"
  CHECK ("varianceCents" IS NULL OR "varianceCents" = 0
         OR length(btrim(COALESCE("varianceReason", ''))) >= 3);

ALTER TABLE "cash_sessions"
  ADD CONSTRAINT "sessions_float_non_negative_check"
  CHECK ("openingFloatCents" >= 0);

-- La diferencia es SIEMPRE contado − esperado. Fijarlo en la base impide que
-- una corrección futura invierta el signo y convierta faltantes en sobrantes.
ALTER TABLE "cash_sessions"
  ADD CONSTRAINT "sessions_variance_definition_check"
  CHECK ("varianceCents" IS NULL
         OR ("countedCashCents" IS NOT NULL AND "expectedCashCents" IS NOT NULL
             AND "varianceCents" = "countedCashCents" - "expectedCashCents"));

ALTER TABLE "cash_sessions"
  ADD CONSTRAINT "sessions_closed_has_closer_check"
  CHECK ("status" = 'OPEN' OR ("closedByUserId" IS NOT NULL AND "closedAt" IS NOT NULL));

-- ── Movimientos de caja ────────────────────────────────────────────────────
ALTER TABLE "cash_movements"
  ADD CONSTRAINT "movements_amount_not_zero_check"
  CHECK ("amountCents" <> 0);

-- Coherencia entre el tipo y el signo. Un "retiro" que METE dinero al cajón
-- es un error de captura que descuadraría el corte sin dejar rastro del porqué.
ALTER TABLE "cash_movements"
  ADD CONSTRAINT "movements_sign_coherence_check"
  CHECK (
    ("movementType" = 'FLOAT_IN' AND "amountCents" > 0)
    OR ("movementType" IN ('WITHDRAWAL', 'EXPENSE', 'DEPOSIT') AND "amountCents" < 0)
    OR ("movementType" = 'CORRECTION')
  );

ALTER TABLE "cash_movements"
  ADD CONSTRAINT "movements_reason_not_blank_check"
  CHECK (length(btrim("reason")) >= 3);

-- ── Motivo de catálogo en los descuentos ───────────────────────────────────
-- NOT VALID a propósito: hay ajustes creados antes del catálogo y falsificar
-- su motivo para satisfacer una restricción sería peor que dejarlos nulos.
-- La restricción rige para todo lo que se escriba de aquí en adelante.
ALTER TABLE "charge_adjustments"
  ADD CONSTRAINT "adjustments_discount_requires_reason_code_check"
  CHECK ("adjustmentType" NOT IN ('DISCOUNT', 'WAIVER') OR "reasonCode" IS NOT NULL)
  NOT VALID;

-- ── Append-only ────────────────────────────────────────────────────────────
-- Un retiro borrado es exactamente el fraude que el corte existe para detectar.
CREATE TRIGGER cash_movements_append_only
  BEFORE UPDATE OR DELETE ON "cash_movements"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

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
