-- CreateEnum
CREATE TYPE "MembershipStatus" AS ENUM ('PENDING', 'TRIALING', 'ACTIVE', 'PAST_DUE', 'FROZEN', 'SUSPENDED', 'CANCELED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "MembershipEventType" AS ENUM ('CREATED', 'ACTIVATED', 'TRIAL_STARTED', 'FROZEN', 'UNFROZEN', 'PLAN_CHANGED', 'RENEWED', 'PAST_DUE', 'SUSPENDED', 'REACTIVATED', 'CANCELED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "VisitPackStatus" AS ENUM ('PENDING_PAYMENT', 'ACTIVE', 'EXHAUSTED', 'EXPIRED', 'FROZEN');

-- CreateEnum
CREATE TYPE "VisitLedgerEntryType" AS ENUM ('PURCHASE', 'CONSUME', 'EXPIRE', 'ADJUST', 'REFUND');

-- DropIndex
DROP INDEX "members_code_trgm_idx";

-- DropIndex
DROP INDEX "members_name_trgm_idx";

-- DropIndex
DROP INDEX "prospects_name_trgm_idx";

-- CreateTable
CREATE TABLE "memberships" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "planId" UUID NOT NULL,
    "soldAtBranchId" UUID,
    "status" "MembershipStatus" NOT NULL DEFAULT 'PENDING',
    "startDate" DATE NOT NULL,
    "currentPeriodStart" DATE NOT NULL,
    "currentPeriodEnd" DATE NOT NULL,
    "billingAnchorDay" INTEGER NOT NULL,
    "graceUntil" DATE,
    "autoRenew" BOOLEAN NOT NULL DEFAULT true,
    "frozenDaysUsedThisYear" INTEGER NOT NULL DEFAULT 0,
    "frozenDaysUsedYear" INTEGER,
    "frozenSince" DATE,
    "frozenUntil" DATE,
    "replacesMembershipId" UUID,
    "canceledAt" TIMESTAMPTZ(3),
    "cancellationReason" TEXT,
    "endedAt" TIMESTAMPTZ(3),
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "memberships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "membership_branch_access" (
    "membershipId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "organizationId" UUID NOT NULL,

    CONSTRAINT "membership_branch_access_pkey" PRIMARY KEY ("membershipId","branchId")
);

-- CreateTable
CREATE TABLE "membership_events" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "membershipId" UUID NOT NULL,
    "branchId" UUID,
    "eventType" "MembershipEventType" NOT NULL,
    "fromStatus" "MembershipStatus",
    "toStatus" "MembershipStatus" NOT NULL,
    "payload" JSONB NOT NULL DEFAULT '{}',
    "actorUserId" UUID,
    "reason" TEXT,
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,

    CONSTRAINT "membership_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_packs" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "planId" UUID,
    "soldAtBranchId" UUID,
    "visitsPurchased" INTEGER NOT NULL,
    "purchasedOn" DATE NOT NULL,
    "expiresOn" DATE,
    "status" "VisitPackStatus" NOT NULL DEFAULT 'PENDING_PAYMENT',
    "expiredAt" TIMESTAMPTZ(3),
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "visit_packs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_ledger_entries" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "visitPackId" UUID NOT NULL,
    "branchId" UUID,
    "attendanceEventId" UUID,
    "entryType" "VisitLedgerEntryType" NOT NULL,
    "delta" INTEGER NOT NULL,
    "reason" TEXT,
    "createdByUserId" UUID,
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,

    CONSTRAINT "visit_ledger_entries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "memberships_replacesMembershipId_key" ON "memberships"("replacesMembershipId");

-- CreateIndex
CREATE INDEX "memberships_organizationId_status_currentPeriodEnd_idx" ON "memberships"("organizationId", "status", "currentPeriodEnd");

-- CreateIndex
CREATE INDEX "memberships_organizationId_memberId_startDate_idx" ON "memberships"("organizationId", "memberId", "startDate" DESC);

-- CreateIndex
CREATE INDEX "memberships_organizationId_status_graceUntil_idx" ON "memberships"("organizationId", "status", "graceUntil");

-- CreateIndex
CREATE UNIQUE INDEX "memberships_id_org_key" ON "memberships"("id", "organizationId");

-- CreateIndex
CREATE INDEX "membership_branch_access_organizationId_branchId_idx" ON "membership_branch_access"("organizationId", "branchId");

-- CreateIndex
CREATE INDEX "membership_events_organizationId_membershipId_at_idx" ON "membership_events"("organizationId", "membershipId", "at" DESC);

-- CreateIndex
CREATE INDEX "visit_packs_organizationId_memberId_status_idx" ON "visit_packs"("organizationId", "memberId", "status");

-- CreateIndex
CREATE INDEX "visit_packs_organizationId_status_expiresOn_idx" ON "visit_packs"("organizationId", "status", "expiresOn");

-- CreateIndex
CREATE UNIQUE INDEX "visit_packs_id_org_key" ON "visit_packs"("id", "organizationId");

-- CreateIndex
CREATE INDEX "visit_ledger_entries_visitPackId_at_idx" ON "visit_ledger_entries"("visitPackId", "at");

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_plan_same_org_fk" FOREIGN KEY ("planId", "organizationId") REFERENCES "plans"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_branch_same_org_fk" FOREIGN KEY ("soldAtBranchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_replacesMembershipId_fkey" FOREIGN KEY ("replacesMembershipId") REFERENCES "memberships"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "membership_branch_access" ADD CONSTRAINT "membership_branch_access_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "memberships"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "membership_branch_access" ADD CONSTRAINT "mba_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "membership_events" ADD CONSTRAINT "membership_events_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "memberships"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_packs" ADD CONSTRAINT "visit_packs_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_ledger_entries" ADD CONSTRAINT "vle_pack_same_org_fk" FOREIGN KEY ("visitPackId", "organizationId") REFERENCES "visit_packs"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ============================================================================
-- Garantías estructurales del Sprint 3.
-- Referencias: ADR-011 (estados), ADR-024 (paquetes), docs/05 §6
-- ============================================================================

-- ── LA constraint crítica del motor ─────────────────────────────────────────
-- Una sola membresía VIGENTE por socio. Sin esto, la doble facturación es
-- cuestión de tiempo: dos altas simultáneas, o una reactivación mal hecha,
-- dejan al socio con dos contratos cobrando en paralelo.
CREATE UNIQUE INDEX "memberships_one_live_per_member"
  ON "memberships" ("memberId")
  WHERE "status" IN ('PENDING','TRIALING','ACTIVE','PAST_DUE','FROZEN');

-- ── Coherencia del contrato ─────────────────────────────────────────────────
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_anchor_range_chk"
  CHECK ("billingAnchorDay" BETWEEN 1 AND 31);

-- Intervalo SEMIABIERTO: el fin siempre es posterior al inicio.
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_period_order_chk"
  CHECK ("currentPeriodEnd" > "currentPeriodStart");

-- La gracia no puede terminar antes del corte que la origina.
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_grace_order_chk"
  CHECK ("graceUntil" IS NULL OR "graceUntil" >= "currentPeriodEnd");

ALTER TABLE "memberships" ADD CONSTRAINT "memberships_freeze_days_chk"
  CHECK ("frozenDaysUsedThisYear" >= 0);

-- Cancelar exige motivo, igual que en la máquina de estados del dominio.
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_cancel_reason_chk"
  CHECK ("status" <> 'CANCELED' OR "cancellationReason" IS NOT NULL);

-- Una membresía congelada debe declarar desde cuándo.
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_frozen_since_chk"
  CHECK ("status" <> 'FROZEN' OR "frozenSince" IS NOT NULL);

-- ── Paquetes de visitas ─────────────────────────────────────────────────────
ALTER TABLE "visit_packs" ADD CONSTRAINT "visit_packs_purchased_positive_chk"
  CHECK ("visitsPurchased" > 0);

-- Un paquete marcado como caducado debe tener la fecha del EVENTO.
ALTER TABLE "visit_packs" ADD CONSTRAINT "visit_packs_expired_event_chk"
  CHECK ("status" <> 'EXPIRED' OR "expiredAt" IS NOT NULL);

-- ANTI DOBLE CONSUMO. Constraint de base de datos, no validación de
-- aplicación: un doble paso del torniquete o una resincronización de eventos
-- offline consumirían dos visitas por una sola entrada, y eso es dinero
-- del socio.
CREATE UNIQUE INDEX "visit_ledger_one_per_attendance"
  ON "visit_ledger_entries" ("visitPackId", "attendanceEventId")
  WHERE "attendanceEventId" IS NOT NULL;

-- Un movimiento de cero no significa nada y ensucia el libro.
ALTER TABLE "visit_ledger_entries" ADD CONSTRAINT "vle_delta_nonzero_chk"
  CHECK ("delta" <> 0);

-- El signo debe corresponder al tipo: una compra no puede restar visitas.
ALTER TABLE "visit_ledger_entries" ADD CONSTRAINT "vle_sign_coherence_chk"
  CHECK (
    ("entryType" = 'PURCHASE' AND "delta" > 0)
    OR ("entryType" = 'CONSUME' AND "delta" < 0)
    OR ("entryType" = 'EXPIRE'  AND "delta" < 0)
    OR ("entryType" = 'REFUND'  AND "delta" < 0)
    OR "entryType" = 'ADJUST'
  );

-- Un ajuste manual SIEMPRE lleva motivo (§28).
ALTER TABLE "visit_ledger_entries" ADD CONSTRAINT "vle_adjust_reason_chk"
  CHECK ("entryType" <> 'ADJUST' OR "reason" IS NOT NULL);

-- El libro de visitas es append-only: un consumo no se reescribe, se
-- compensa con un ajuste que deja rastro.
CREATE OR REPLACE FUNCTION gymflow_visit_ledger_is_append_only()
RETURNS trigger LANGUAGE plpgsql AS $FN$
BEGIN
  RAISE EXCEPTION 'visit_ledger_entries es append-only: % no está permitido. Compensa con un ADJUST', TG_OP
    USING ERRCODE = 'restrict_violation';
END;
$FN$;

CREATE TRIGGER "visit_ledger_no_update"
  BEFORE UPDATE ON "visit_ledger_entries"
  FOR EACH ROW EXECUTE FUNCTION gymflow_visit_ledger_is_append_only();

CREATE TRIGGER "visit_ledger_no_delete"
  BEFORE DELETE ON "visit_ledger_entries"
  FOR EACH ROW EXECUTE FUNCTION gymflow_visit_ledger_is_append_only();

-- La bitácora de transiciones también es historia, no estado editable.
CREATE TRIGGER "membership_events_no_update"
  BEFORE UPDATE ON "membership_events"
  FOR EACH ROW EXECUTE FUNCTION gymflow_audit_is_append_only();

CREATE TRIGGER "membership_events_no_delete"
  BEFORE DELETE ON "membership_events"
  FOR EACH ROW EXECUTE FUNCTION gymflow_audit_is_append_only();

-- ── Privilegios ─────────────────────────────────────────────────────────────
-- RECORDATORIO: un `GRANT ... ON ALL TABLES` DESHACE los REVOKE anteriores.
-- Por eso se re-aplican TODOS aquí, y hay pruebas que lo verifican.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO gymflow_app;

REVOKE UPDATE, DELETE ON "audit_logs" FROM gymflow_app;
REVOKE DELETE ON "member_consents" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "visit_ledger_entries" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "membership_events" FROM gymflow_app;
