-- CreateEnum
CREATE TYPE "ConsentDocumentStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'RETIRED');

-- CreateEnum
CREATE TYPE "MemberIntakeStatus" AS ENUM ('SUBMITTED', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "ClassOccurrenceStatus" AS ENUM ('SCHEDULED', 'CANCELED', 'CLOSED');

-- CreateEnum
CREATE TYPE "ClassBookingStatus" AS ENUM ('BOOKED', 'CANCELED', 'ATTENDED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "ClassBookingSource" AS ENUM ('PORTAL', 'FRONT_DESK');

-- AlterTable
ALTER TABLE "plans" ADD COLUMN     "includesClasses" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "consent_documents" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "consentType" "ConsentType" NOT NULL,
    "version" TEXT NOT NULL,
    "status" "ConsentDocumentStatus" NOT NULL DEFAULT 'DRAFT',
    "title" TEXT NOT NULL,
    "bodyText" TEXT NOT NULL,
    "bodyHash" TEXT,
    "publishedAt" TIMESTAMPTZ(3),
    "publishedByUserId" UUID,
    "retiredAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "consent_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_intakes" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "status" "MemberIntakeStatus" NOT NULL DEFAULT 'SUBMITTED',
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "nameKey" TEXT NOT NULL,
    "phoneE164" TEXT,
    "email" TEXT,
    "birthDate" DATE,
    "emergencyContactName" TEXT,
    "emergencyContactPhone" TEXT,
    "memberSince" DATE,
    "healthNotes" TEXT,
    "acceptedConsents" JSONB NOT NULL,
    "ip" TEXT,
    "userAgent" TEXT,
    "submittedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewedAt" TIMESTAMPTZ(3),
    "reviewedByUserId" UUID,
    "rejectionReason" TEXT,
    "memberId" UUID,

    CONSTRAINT "member_intakes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "class_types" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "defaultDurationMin" INTEGER NOT NULL DEFAULT 60,
    "defaultCapacity" INTEGER NOT NULL DEFAULT 20,
    "dropInPriceCents" BIGINT NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "class_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "class_templates" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "classTypeId" UUID NOT NULL,
    "coachUserId" UUID,
    "room" TEXT,
    "effectiveFrom" DATE NOT NULL,
    "effectiveTo" DATE,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "class_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "class_template_slots" (
    "id" UUID NOT NULL,
    "templateId" UUID NOT NULL,
    "weekday" SMALLINT NOT NULL,
    "startMinute" SMALLINT NOT NULL,
    "durationMin" SMALLINT NOT NULL,
    "capacity" SMALLINT NOT NULL,

    CONSTRAINT "class_template_slots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "class_schedules" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "classTypeId" UUID NOT NULL,
    "templateId" UUID,
    "coachUserId" UUID,
    "room" TEXT,
    "occurrenceKey" TEXT NOT NULL,
    "startsAt" TIMESTAMPTZ(3) NOT NULL,
    "endsAt" TIMESTAMPTZ(3) NOT NULL,
    "businessDate" DATE NOT NULL,
    "capacity" INTEGER NOT NULL,
    "bookedCount" INTEGER NOT NULL DEFAULT 0,
    "status" "ClassOccurrenceStatus" NOT NULL DEFAULT 'SCHEDULED',
    "wallTimeResolution" TEXT NOT NULL DEFAULT 'EXACT',
    "canceledAt" TIMESTAMPTZ(3),
    "cancelReason" TEXT,
    "closedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "class_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "class_bookings" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "classScheduleId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "status" "ClassBookingStatus" NOT NULL DEFAULT 'BOOKED',
    "source" "ClassBookingSource" NOT NULL DEFAULT 'FRONT_DESK',
    "chargeId" UUID,
    "bookedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "bookedByUserId" UUID,
    "canceledAt" TIMESTAMPTZ(3),
    "lateCancel" BOOLEAN NOT NULL DEFAULT false,
    "checkedInAt" TIMESTAMPTZ(3),
    "closedAt" TIMESTAMPTZ(3),

    CONSTRAINT "class_bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "class_booking_blocks" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "untilDate" TIMESTAMPTZ(3) NOT NULL,
    "noShowCount" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "class_booking_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "consent_documents_organizationId_status_idx" ON "consent_documents"("organizationId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "consent_documents_organizationId_consentType_version_key" ON "consent_documents"("organizationId", "consentType", "version");

-- CreateIndex
CREATE UNIQUE INDEX "member_intakes_memberId_key" ON "member_intakes"("memberId");

-- CreateIndex
CREATE INDEX "intakes_name_trgm_idx" ON "member_intakes" USING GIN ("nameKey" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "member_intakes_organizationId_status_submittedAt_idx" ON "member_intakes"("organizationId", "status", "submittedAt" DESC);

-- CreateIndex
CREATE INDEX "class_types_organizationId_isActive_idx" ON "class_types"("organizationId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "class_types_id_org_key" ON "class_types"("id", "organizationId");

-- CreateIndex
CREATE INDEX "class_templates_organizationId_branchId_isActive_idx" ON "class_templates"("organizationId", "branchId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "class_template_slots_templateId_weekday_startMinute_key" ON "class_template_slots"("templateId", "weekday", "startMinute");

-- CreateIndex
CREATE INDEX "class_schedules_organizationId_branchId_businessDate_idx" ON "class_schedules"("organizationId", "branchId", "businessDate");

-- CreateIndex
CREATE INDEX "class_schedules_organizationId_startsAt_idx" ON "class_schedules"("organizationId", "startsAt");

-- CreateIndex
CREATE UNIQUE INDEX "class_schedules_organizationId_occurrenceKey_key" ON "class_schedules"("organizationId", "occurrenceKey");

-- CreateIndex
CREATE UNIQUE INDEX "class_schedules_id_org_key" ON "class_schedules"("id", "organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "class_bookings_chargeId_key" ON "class_bookings"("chargeId");

-- CreateIndex
CREATE INDEX "class_bookings_organizationId_memberId_bookedAt_idx" ON "class_bookings"("organizationId", "memberId", "bookedAt" DESC);

-- CreateIndex
CREATE INDEX "class_bookings_classScheduleId_status_idx" ON "class_bookings"("classScheduleId", "status");

-- CreateIndex
CREATE INDEX "class_booking_blocks_organizationId_memberId_untilDate_idx" ON "class_booking_blocks"("organizationId", "memberId", "untilDate" DESC);

-- AddForeignKey
ALTER TABLE "consent_documents" ADD CONSTRAINT "consent_documents_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_intakes" ADD CONSTRAINT "member_intakes_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_intakes" ADD CONSTRAINT "intakes_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_intakes" ADD CONSTRAINT "member_intakes_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_types" ADD CONSTRAINT "class_types_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_templates" ADD CONSTRAINT "class_templates_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_templates" ADD CONSTRAINT "class_templates_type_same_org_fk" FOREIGN KEY ("classTypeId", "organizationId") REFERENCES "class_types"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_template_slots" ADD CONSTRAINT "class_template_slots_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "class_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_schedules" ADD CONSTRAINT "class_schedules_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_schedules" ADD CONSTRAINT "class_schedules_type_same_org_fk" FOREIGN KEY ("classTypeId", "organizationId") REFERENCES "class_types"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_schedules" ADD CONSTRAINT "class_schedules_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "class_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_bookings" ADD CONSTRAINT "class_bookings_schedule_same_org_fk" FOREIGN KEY ("classScheduleId", "organizationId") REFERENCES "class_schedules"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_bookings" ADD CONSTRAINT "class_bookings_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_bookings" ADD CONSTRAINT "class_bookings_chargeId_fkey" FOREIGN KEY ("chargeId") REFERENCES "charges"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "class_booking_blocks" ADD CONSTRAINT "booking_blocks_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ── Índices parciales ──────────────────────────────────────────────────────
-- Prisma NO sabe representarlos; van aquí y solo aquí.

-- UNA sola versión vigente por tipo de consentimiento. Dos textos publicados
-- a la vez significa que nadie puede decir cuál firmó el socio.
CREATE UNIQUE INDEX "consent_documents_one_published_idx"
  ON "consent_documents" ("organizationId", "consentType")
  WHERE "status" = 'PUBLISHED';

CREATE UNIQUE INDEX "class_types_name_unique_idx"
  ON "class_types" ("organizationId", "name")
  WHERE "deletedAt" IS NULL;

-- La doble reserva se impide en la BASE. Dos pulsaciones simultáneas del
-- mismo socio ganan a cualquier comprobación hecha antes de escribir.
CREATE UNIQUE INDEX "class_bookings_one_active_idx"
  ON "class_bookings" ("classScheduleId", "memberId")
  WHERE "status" <> 'CANCELED';

-- ── Invariantes ────────────────────────────────────────────────────────────

ALTER TABLE "member_intakes"
  ADD CONSTRAINT "member_intakes_approved_has_member_check"
  CHECK (("status" = 'APPROVED') = ("memberId" IS NOT NULL));

ALTER TABLE "member_intakes"
  ADD CONSTRAINT "member_intakes_rejected_has_reason_check"
  CHECK ("status" <> 'REJECTED' OR "rejectionReason" IS NOT NULL);

ALTER TABLE "class_templates"
  ADD CONSTRAINT "class_templates_period_check"
  CHECK ("effectiveTo" IS NULL OR "effectiveTo" > "effectiveFrom");

ALTER TABLE "class_template_slots"
  ADD CONSTRAINT "class_template_slots_sane_check"
  CHECK ("weekday" BETWEEN 0 AND 6
     AND "startMinute" BETWEEN 0 AND 1439
     AND "durationMin" > 0 AND "durationMin" <= 480
     AND "capacity" > 0);

-- El cupo. Esta restricción es la que convierte
-- `UPDATE ... WHERE bookedCount < capacity` en una garantía y no en una
-- costumbre; y de paso impide bajar el cupo por debajo de lo ya reservado,
-- que expulsaría en silencio a quien ya tenía plaza.
ALTER TABLE "class_schedules"
  ADD CONSTRAINT "class_schedules_capacity_check"
  CHECK ("bookedCount" >= 0 AND "bookedCount" <= "capacity" AND "capacity" > 0);

ALTER TABLE "class_schedules"
  ADD CONSTRAINT "class_schedules_interval_check"
  CHECK ("endsAt" > "startsAt");

ALTER TABLE "class_schedules"
  ADD CONSTRAINT "class_schedules_canceled_check"
  CHECK (("status" = 'CANCELED') = ("canceledAt" IS NOT NULL));

ALTER TABLE "class_bookings"
  ADD CONSTRAINT "class_bookings_canceled_check"
  CHECK (("status" = 'CANCELED') = ("canceledAt" IS NOT NULL));

ALTER TABLE "class_booking_blocks"
  ADD CONSTRAINT "class_booking_blocks_count_check"
  CHECK ("noShowCount" > 0);

-- ── Inmutabilidad del texto publicado ──────────────────────────────────────
-- Un consentimiento cuyo texto se puede editar después de firmado NO es
-- evidencia: es una afirmación. El socio aceptó unas palabras concretas y
-- esas palabras tienen que seguir siendo las mismas dentro de tres años.
CREATE OR REPLACE FUNCTION consent_document_immutable() RETURNS trigger AS $$
BEGIN
  IF OLD."status" = 'PUBLISHED' THEN
    IF NEW."bodyText" IS DISTINCT FROM OLD."bodyText"
       OR NEW."version" IS DISTINCT FROM OLD."version"
       OR NEW."consentType" IS DISTINCT FROM OLD."consentType"
       OR NEW."publishedAt" IS DISTINCT FROM OLD."publishedAt" THEN
      RAISE EXCEPTION 'consent_documents: un documento PUBLICADO es inmutable; publique una versión nueva';
    END IF;
    -- De publicado solo se sale hacia retirado.
    IF NEW."status" NOT IN ('PUBLISHED', 'RETIRED') THEN
      RAISE EXCEPTION 'consent_documents: un documento PUBLICADO no vuelve a borrador';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER consent_document_immutable_trg
  BEFORE UPDATE ON "consent_documents"
  FOR EACH ROW EXECUTE FUNCTION consent_document_immutable();

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
-- Nuevas del Sprint 11. El borrador del alta y la sanción son evidencia:
-- borrar una sanción por faltas a mano es exactamente el fraude interno que
-- ADR-018 existe para impedir.
REVOKE DELETE ON "consent_documents" FROM gymflow_app;
REVOKE DELETE ON "member_intakes" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "class_booking_blocks" FROM gymflow_app;
