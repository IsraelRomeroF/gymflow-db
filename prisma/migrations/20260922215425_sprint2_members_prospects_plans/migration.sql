-- ── Extensiones requeridas por el esquema ───────────────────────────────────
-- Viven en la migración, NO solo en el script de bootstrap: cualquier base
-- creada desde cero (shadow, CI, un entorno nuevo) las necesita.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CreateEnum
CREATE TYPE "MemberStatus" AS ENUM ('PROSPECT', 'ACTIVE', 'INACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "BillingModel" AS ENUM ('RECURRING', 'PREPAID_PERIOD', 'VISIT_PACK', 'DAY_PASS');

-- CreateEnum
CREATE TYPE "DurationUnit" AS ENUM ('DAY', 'WEEK', 'MONTH', 'VISIT');

-- CreateEnum
CREATE TYPE "BranchAccessScope" AS ENUM ('HOME_BRANCH', 'LISTED_BRANCHES', 'ALL_BRANCHES');

-- CreateEnum
CREATE TYPE "ProspectStatus" AS ENUM ('NEW', 'CONTACTED', 'VISITED', 'TRIAL', 'CONVERTED', 'LOST');

-- CreateEnum
CREATE TYPE "ConsentType" AS ENUM ('PRIVACY_NOTICE', 'BIOMETRIC', 'RECURRING_CHARGE', 'MARKETING', 'HOUSE_RULES', 'HEALTH_DATA');

-- DropForeignKey
ALTER TABLE "role_assignments" DROP CONSTRAINT "role_assignments_branchId_fkey";

-- DropForeignKey
ALTER TABLE "role_assignments" DROP CONSTRAINT "role_assignments_userId_fkey";

-- CreateTable
CREATE TABLE "members" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberCode" TEXT NOT NULL,
    "homeBranchId" UUID,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "nameKey" TEXT NOT NULL,
    "phoneE164" TEXT,
    "email" TEXT,
    "birthDate" DATE,
    "curp" TEXT,
    "photoObjectKey" TEXT,
    "notes" TEXT,
    "status" "MemberStatus" NOT NULL DEFAULT 'ACTIVE',
    "balanceCentsCached" BIGINT NOT NULL DEFAULT 0,
    "balanceComputedAt" TIMESTAMPTZ(3),
    "joinedAt" TIMESTAMPTZ(3) NOT NULL,
    "anonymizedAt" TIMESTAMPTZ(3),
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_consents" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "branchId" UUID,
    "consentType" "ConsentType" NOT NULL,
    "documentVersion" TEXT NOT NULL,
    "documentText" TEXT,
    "granted" BOOLEAN NOT NULL,
    "grantedAt" TIMESTAMPTZ(3) NOT NULL,
    "revokedAt" TIMESTAMPTZ(3),
    "evidenceObjectKey" TEXT,
    "ip" TEXT,
    "userAgent" TEXT,
    "channel" TEXT,
    "assistedByUserId" UUID,
    "evidenceHash" TEXT,

    CONSTRAINT "member_consents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prospects" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "nameKey" TEXT NOT NULL,
    "phoneE164" TEXT,
    "email" TEXT,
    "source" TEXT,
    "status" "ProspectStatus" NOT NULL DEFAULT 'NEW',
    "assignedToUserId" UUID,
    "convertedMemberId" UUID,
    "convertedAt" TIMESTAMPTZ(3),
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "prospects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plans" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "billingModel" "BillingModel" NOT NULL,
    "durationUnit" "DurationUnit" NOT NULL,
    "durationValue" INTEGER NOT NULL,
    "priceCents" BIGINT NOT NULL,
    "signupFeeCents" BIGINT NOT NULL DEFAULT 0,
    "currency" CHAR(3) NOT NULL DEFAULT 'MXN',
    "taxRateBps" INTEGER,
    "priceIncludesTax" BOOLEAN NOT NULL DEFAULT true,
    "branchAccessScope" "BranchAccessScope" NOT NULL DEFAULT 'ALL_BRANCHES',
    "visitsPerPeriodAtNonHomeBranch" INTEGER,
    "accessTimeWindows" JSONB,
    "visitsIncluded" INTEGER,
    "visitValidityDays" INTEGER,
    "defaultGraceDays" INTEGER NOT NULL DEFAULT 5,
    "allowFreeze" BOOLEAN NOT NULL DEFAULT true,
    "maxFreezeDaysPerYear" INTEGER NOT NULL DEFAULT 30,
    "minFreezeDays" INTEGER NOT NULL DEFAULT 7,
    "autoRenewDefault" BOOLEAN NOT NULL DEFAULT true,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plan_branch_availability" (
    "planId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "isAvailable" BOOLEAN NOT NULL DEFAULT true,
    "priceOverrideCents" BIGINT,

    CONSTRAINT "plan_branch_availability_pkey" PRIMARY KEY ("planId","branchId")
);

-- CreateTable
CREATE TABLE "member_code_counters" (
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "lastSequence" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "member_code_counters_pkey" PRIMARY KEY ("organizationId","branchId")
);

-- CreateIndex
CREATE INDEX "members_organizationId_status_homeBranchId_idx" ON "members"("organizationId", "status", "homeBranchId");

-- CreateIndex
CREATE INDEX "members_organizationId_joinedAt_idx" ON "members"("organizationId", "joinedAt");

-- CreateIndex
CREATE UNIQUE INDEX "members_id_org_key" ON "members"("id", "organizationId");

-- CreateIndex
CREATE INDEX "member_consents_organizationId_memberId_consentType_granted_idx" ON "member_consents"("organizationId", "memberId", "consentType", "grantedAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "prospects_convertedMemberId_key" ON "prospects"("convertedMemberId");

-- CreateIndex
CREATE INDEX "prospects_organizationId_branchId_status_createdAt_idx" ON "prospects"("organizationId", "branchId", "status", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "plans_organizationId_isActive_billingModel_idx" ON "plans"("organizationId", "isActive", "billingModel");

-- CreateIndex
CREATE UNIQUE INDEX "plans_id_org_key" ON "plans"("id", "organizationId");

-- CreateIndex
CREATE INDEX "plan_branch_availability_organizationId_branchId_idx" ON "plan_branch_availability"("organizationId", "branchId");

-- CreateIndex
CREATE INDEX "audit_logs_chain_tip_idx" ON "audit_logs"("organizationId", "at" DESC, "id" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "branches_id_org_key" ON "branches"("id", "organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "users_id_org_key" ON "users"("id", "organizationId");

-- AddForeignKey
ALTER TABLE "role_assignments" ADD CONSTRAINT "role_assignments_user_same_org_fk" FOREIGN KEY ("userId", "organizationId") REFERENCES "users"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_assignments" ADD CONSTRAINT "role_assignments_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "members" ADD CONSTRAINT "members_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "members" ADD CONSTRAINT "members_home_branch_same_org_fk" FOREIGN KEY ("homeBranchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prospects" ADD CONSTRAINT "prospects_convertedMemberId_fkey" FOREIGN KEY ("convertedMemberId") REFERENCES "members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plans" ADD CONSTRAINT "plans_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_branch_availability" ADD CONSTRAINT "pba_plan_same_org_fk" FOREIGN KEY ("planId", "organizationId") REFERENCES "plans"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_branch_availability" ADD CONSTRAINT "pba_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ── Unicidad reutilizable tras baja lógica ──────────────────────────────────
CREATE UNIQUE INDEX "members_org_code_active_key"
  ON "members" ("organizationId", "memberCode") WHERE "deletedAt" IS NULL;

CREATE UNIQUE INDEX "members_org_phone_active_key"
  ON "members" ("organizationId", "phoneE164")
  WHERE "deletedAt" IS NULL AND "phoneE164" IS NOT NULL;

CREATE UNIQUE INDEX "plans_org_code_active_key"
  ON "plans" ("organizationId", "code") WHERE "deletedAt" IS NULL;

-- ── Busqueda en recepcion con errores de captura ────────────────────────────
CREATE INDEX "members_name_trgm_idx" ON "members" USING gin ("nameKey" gin_trgm_ops);
CREATE INDEX "members_code_trgm_idx" ON "members" USING gin ("memberCode" gin_trgm_ops);
CREATE INDEX "prospects_name_trgm_idx" ON "prospects" USING gin ("nameKey" gin_trgm_ops);

-- ── FKs compuestas que cruzan el tenant ─────────────────────────────────────
-- Se declaran en schema.prisma como relaciones compuestas con `map:`, de modo
-- que Prisma las genera arriba. Mantenerlas aquí las duplicaría.

-- ── Coherencia del catalogo de planes ───────────────────────────────────────
ALTER TABLE "plans" ADD CONSTRAINT "plans_visitpack_coherence_chk"
  CHECK ("billingModel" <> 'VISIT_PACK' OR ("visitsIncluded" IS NOT NULL AND "visitsIncluded" > 0));
ALTER TABLE "plans" ADD CONSTRAINT "plans_visit_unit_coherence_chk"
  CHECK (("durationUnit" = 'VISIT') = ("billingModel" = 'VISIT_PACK'));
ALTER TABLE "plans" ADD CONSTRAINT "plans_price_nonnegative_chk"
  CHECK ("priceCents" >= 0 AND "signupFeeCents" >= 0);
ALTER TABLE "plans" ADD CONSTRAINT "plans_duration_positive_chk"
  CHECK ("durationValue" > 0);
ALTER TABLE "plans" ADD CONSTRAINT "plans_tax_rate_range_chk"
  CHECK ("taxRateBps" IS NULL OR ("taxRateBps" >= 0 AND "taxRateBps" <= 10000));
ALTER TABLE "plans" ADD CONSTRAINT "plans_freeze_coherence_chk"
  CHECK (NOT "allowFreeze" OR "maxFreezeDaysPerYear" >= "minFreezeDays");

-- ── Coherencia de consentimientos ───────────────────────────────────────────
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_revocation_order_chk"
  CHECK ("revokedAt" IS NULL OR "revokedAt" >= "grantedAt");

CREATE OR REPLACE FUNCTION gymflow_consent_is_immutable()
RETURNS trigger LANGUAGE plpgsql AS $FN$
BEGIN
  IF NEW."documentVersion" IS DISTINCT FROM OLD."documentVersion"
     OR NEW."documentText" IS DISTINCT FROM OLD."documentText"
     OR NEW."grantedAt" IS DISTINCT FROM OLD."grantedAt"
     OR NEW."granted" IS DISTINCT FROM OLD."granted"
     OR NEW."evidenceHash" IS DISTINCT FROM OLD."evidenceHash" THEN
    RAISE EXCEPTION 'La evidencia de consentimiento es inmutable; solo puede revocarse'
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END;
$FN$;

CREATE TRIGGER "member_consents_immutable"
  BEFORE UPDATE ON "member_consents"
  FOR EACH ROW EXECUTE FUNCTION gymflow_consent_is_immutable();

-- ── Privilegios ─────────────────────────────────────────────────────────────
-- ATENCIÓN: un `GRANT ... ON ALL TABLES` DESHACE los REVOKE de migraciones
-- anteriores. Por eso los REVOKE se vuelven a aplicar SIEMPRE después del
-- GRANT, y una prueba de integración verifica el resultado.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO gymflow_app;

-- La bitácora es append-only (ADR-018). Se re-revoca tras el GRANT anterior.
REVOKE UPDATE, DELETE ON "audit_logs" FROM gymflow_app;
-- La evidencia de consentimiento no se borra: es prueba de cumplimiento.
REVOKE DELETE ON "member_consents" FROM gymflow_app;
