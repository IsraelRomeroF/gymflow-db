-- CreateEnum
CREATE TYPE "BiometricModality" AS ENUM ('FACE', 'FINGERPRINT');

-- AlterEnum
ALTER TYPE "CredentialKind" ADD VALUE 'FACE';

-- AlterTable
ALTER TABLE "access_decisions" ADD COLUMN     "livenessMode" TEXT,
ADD COLUMN     "livenessPassed" BOOLEAN,
ADD COLUMN     "matchMargin" DOUBLE PRECISION,
ADD COLUMN     "matchScore" DOUBLE PRECISION;

-- CreateTable
CREATE TABLE "biometric_enrollments" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "modality" "BiometricModality" NOT NULL,
    "branchId" UUID NOT NULL,
    "templateRef" TEXT NOT NULL,
    "algorithmVendor" TEXT NOT NULL,
    "algorithmVersion" TEXT,
    "consentId" UUID NOT NULL,
    "enrolledByUserId" UUID NOT NULL,
    "enrolledAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMPTZ(3),
    "revokedReason" TEXT,
    "templateDeletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "biometric_enrollments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "biometric_enrollments_organizationId_memberId_modality_idx" ON "biometric_enrollments"("organizationId", "memberId", "modality");

-- CreateIndex
CREATE INDEX "biometric_enrollments_organizationId_branchId_revokedAt_idx" ON "biometric_enrollments"("organizationId", "branchId", "revokedAt");

-- CreateIndex
CREATE INDEX "biometric_enrollments_revokedAt_templateDeletedAt_idx" ON "biometric_enrollments"("revokedAt", "templateDeletedAt");

-- AddForeignKey
ALTER TABLE "biometric_enrollments" ADD CONSTRAINT "biometric_enrollments_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "biometric_enrollments" ADD CONSTRAINT "enrollments_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "biometric_enrollments" ADD CONSTRAINT "enrollments_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "biometric_enrollments" ADD CONSTRAINT "biometric_enrollments_consentId_fkey" FOREIGN KEY ("consentId") REFERENCES "member_consents"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ── Índices parciales ──────────────────────────────────────────────────────

-- UN solo enrolamiento vivo por socio, sede y modalidad. Dos significa que
-- nadie sabe cuál plantilla está en uso ni cuál hay que borrar.
CREATE UNIQUE INDEX "biometric_enrollments_one_live_idx"
  ON "biometric_enrollments" ("memberId", "branchId", "modality")
  WHERE "revokedAt" IS NULL;

-- ── Invariantes ────────────────────────────────────────────────────────────

ALTER TABLE "biometric_enrollments"
  ADD CONSTRAINT "biometric_enrollments_revoked_check"
  CHECK (("revokedAt" IS NULL) = ("revokedReason" IS NULL));

-- No se borra la plantilla de un enrolamiento que sigue vivo. Si esto se
-- pudiera, el socio dejaría de ser reconocido sin que nada lo explicara.
ALTER TABLE "biometric_enrollments"
  ADD CONSTRAINT "biometric_enrollments_deletion_order_check"
  CHECK ("templateDeletedAt" IS NULL OR "revokedAt" IS NOT NULL);

-- La evidencia del reconocimiento vive en rangos conocidos. Un `matchScore`
-- fuera de [0,1] significa que el motor cambió de escala y la calibración del
-- umbral dejó de valer — mejor que reviente a que se compare con basura.
ALTER TABLE "access_decisions"
  ADD CONSTRAINT "access_decisions_match_range_check"
  CHECK (("matchScore" IS NULL OR ("matchScore" >= 0 AND "matchScore" <= 1))
     AND ("matchMargin" IS NULL OR ("matchMargin" >= 0 AND "matchMargin" <= 1)));

ALTER TABLE "access_decisions"
  ADD CONSTRAINT "access_decisions_liveness_mode_check"
  CHECK ("livenessMode" IS NULL OR "livenessMode" IN ('NONE', 'ACTIVE', 'PASSIVE', 'BOTH'));

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
REVOKE DELETE ON "payment_attempts" FROM gymflow_app;
REVOKE DELETE ON "refunds" FROM gymflow_app;
REVOKE DELETE ON "chargebacks" FROM gymflow_app;
REVOKE DELETE ON "webhook_events" FROM gymflow_app;
-- El enrolamiento es la prueba de que hubo consentimiento y de que la
-- plantilla se borró. Se revoca, no se borra: un DELETE aquí destruye
-- exactamente la evidencia que ADR-014 obliga a conservar.
REVOKE DELETE ON "biometric_enrollments" FROM gymflow_app;
