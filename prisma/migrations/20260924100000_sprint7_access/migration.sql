-- CreateEnum
CREATE TYPE "AccessOutcome" AS ENUM ('GRANTED', 'DENIED');

-- CreateEnum
CREATE TYPE "CredentialKind" AS ENUM ('QR', 'RFID', 'PIN', 'FINGERPRINT', 'MANUAL');

-- CreateEnum
CREATE TYPE "GatewayStatus" AS ENUM ('ONLINE', 'DEGRADED', 'OFFLINE');

-- CreateTable
CREATE TABLE "access_gateways" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "status" "GatewayStatus" NOT NULL DEFAULT 'OFFLINE',
    "policyVersion" TEXT,
    "rosterVersion" BIGINT,
    "lastHeartbeatAt" TIMESTAMPTZ(3),
    "certificateFingerprint" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "access_gateways_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "access_decisions" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "gatewayId" UUID,
    "memberId" UUID,
    "outcome" "AccessOutcome" NOT NULL,
    "denialReason" TEXT,
    "credentialKind" "CredentialKind" NOT NULL,
    "policyVersion" TEXT NOT NULL,
    "decidedOffline" BOOLEAN NOT NULL DEFAULT false,
    "overriddenByUserId" UUID,
    "overrideReason" TEXT,
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,

    CONSTRAINT "access_decisions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attendance_events" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "accessDecisionId" UUID NOT NULL,
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,

    CONSTRAINT "attendance_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "access_gateways_organizationId_branchId_status_idx" ON "access_gateways"("organizationId", "branchId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "access_gateways_id_org_key" ON "access_gateways"("id", "organizationId");

-- CreateIndex
CREATE INDEX "access_decisions_organizationId_branchId_businessDate_idx" ON "access_decisions"("organizationId", "branchId", "businessDate");

-- CreateIndex
CREATE INDEX "access_decisions_organizationId_memberId_at_idx" ON "access_decisions"("organizationId", "memberId", "at" DESC);

-- CreateIndex
CREATE INDEX "access_decisions_organizationId_outcome_businessDate_idx" ON "access_decisions"("organizationId", "outcome", "businessDate");

-- CreateIndex
CREATE UNIQUE INDEX "access_decisions_id_org_key" ON "access_decisions"("id", "organizationId");

-- CreateIndex
CREATE INDEX "attendance_events_organizationId_memberId_at_idx" ON "attendance_events"("organizationId", "memberId", "at" DESC);

-- CreateIndex
CREATE INDEX "attendance_events_organizationId_branchId_businessDate_idx" ON "attendance_events"("organizationId", "branchId", "businessDate");

-- CreateIndex
CREATE UNIQUE INDEX "attendance_decision_key" ON "attendance_events"("accessDecisionId");

-- CreateIndex
CREATE UNIQUE INDEX "attendance_decision_org_key" ON "attendance_events"("accessDecisionId", "organizationId");

-- AddForeignKey
ALTER TABLE "access_gateways" ADD CONSTRAINT "access_gateways_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "access_gateways" ADD CONSTRAINT "gateways_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "access_decisions" ADD CONSTRAINT "access_decisions_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "access_decisions" ADD CONSTRAINT "decisions_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "access_decisions" ADD CONSTRAINT "decisions_gateway_same_org_fk" FOREIGN KEY ("gatewayId", "organizationId") REFERENCES "access_gateways"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "access_decisions" ADD CONSTRAINT "decisions_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_events" ADD CONSTRAINT "attendance_events_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_events" ADD CONSTRAINT "attendance_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_events" ADD CONSTRAINT "attendance_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_events" ADD CONSTRAINT "attendance_decision_same_org_fk" FOREIGN KEY ("accessDecisionId", "organizationId") REFERENCES "access_decisions"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ════════════════════════════════════════════════════════════════════════════
-- GARANTÍAS QUE PRISMA NO PUEDE EXPRESAR
-- ════════════════════════════════════════════════════════════════════════════

CREATE UNIQUE INDEX "access_gateways_org_code_key"
  ON "access_gateways" ("organizationId", "code")
  WHERE "deletedAt" IS NULL;

-- Una negativa SIN motivo no sirve para nada: la pantalla de excepción del
-- Sprint 9 existe para convertir el rechazo en transacción, y para eso
-- necesita saber por qué. La equivalencia va en los dos sentidos: un permitido
-- tampoco puede llevar motivo de negativa.
ALTER TABLE "access_decisions"
  ADD CONSTRAINT "decisions_denial_reason_check"
  CHECK (("outcome" = 'DENIED') = ("denialReason" IS NOT NULL));

-- Una concesión manual SIEMPRE lleva quién y por qué. Es el registro que
-- convierte el "déjalo pasar" en un dato y no en un favor invisible.
ALTER TABLE "access_decisions"
  ADD CONSTRAINT "decisions_override_reason_check"
  CHECK ("overriddenByUserId" IS NULL OR length(btrim(COALESCE("overrideReason", ''))) >= 3);

-- La versión de política NO puede faltar: sin ella, un rechazo discutido
-- meses después es irreproducible.
ALTER TABLE "access_decisions"
  ADD CONSTRAINT "decisions_policy_version_check"
  CHECK (length(btrim("policyVersion")) > 0);

-- ── Append-only ────────────────────────────────────────────────────────────
-- La bitácora de acceso es prueba frente al socio: "el día 14 no te dejamos
-- pasar por esto". Editable, no prueba nada.
CREATE TRIGGER access_decisions_append_only
  BEFORE UPDATE OR DELETE ON "access_decisions"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER attendance_events_append_only
  BEFORE UPDATE OR DELETE ON "attendance_events"
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
REVOKE UPDATE, DELETE ON "inventory_movements" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "pos_sale_lines" FROM gymflow_app;
REVOKE DELETE ON "pos_sales" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "access_decisions" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "attendance_events" FROM gymflow_app;
