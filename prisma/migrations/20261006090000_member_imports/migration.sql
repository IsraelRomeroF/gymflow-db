-- CreateTable
CREATE TABLE "member_imports" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "fileName" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'REVIEW',
    "cutoffDate" DATE NOT NULL,
    "planMap" JSONB NOT NULL DEFAULT '{}',
    "branchMap" JSONB NOT NULL DEFAULT '{}',
    "totalRows" INTEGER NOT NULL,
    "createdByUserId" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "appliedAt" TIMESTAMPTZ(3),
    "appliedByUserId" UUID,
    "canceledAt" TIMESTAMPTZ(3),
    "reason" TEXT,

    CONSTRAINT "member_imports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_import_rows" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "importId" UUID NOT NULL,
    "rowNumber" INTEGER NOT NULL,
    "raw" JSONB NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "phoneE164" TEXT,
    "email" TEXT,
    "curp" TEXT,
    "birthDate" DATE,
    "joinedAt" DATE,
    "periodEnd" DATE,
    "legacyCode" TEXT,
    "branchLabel" TEXT,
    "planLabel" TEXT,
    "notes" TEXT,
    "balanceCents" BIGINT,
    "problems" JSONB NOT NULL DEFAULT '[]',
    "kind" TEXT NOT NULL,
    "matchMemberId" UUID,
    "matchRowId" UUID,
    "matchScore" INTEGER,
    "matchReason" TEXT,
    "decision" TEXT NOT NULL,
    "decidedByUserId" UUID,
    "decidedAt" TIMESTAMPTZ(3),
    "appliedMemberId" UUID,
    "appliedAt" TIMESTAMPTZ(3),
    "applyNote" TEXT,

    CONSTRAINT "member_import_rows_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_legacy_codes" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "importId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_legacy_codes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "member_imports_organizationId_createdAt_idx" ON "member_imports"("organizationId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "member_import_rows_importId_kind_idx" ON "member_import_rows"("importId", "kind");

-- CreateIndex
CREATE INDEX "member_import_rows_importId_decision_idx" ON "member_import_rows"("importId", "decision");

-- CreateIndex
CREATE UNIQUE INDEX "member_import_rows_importId_rowNumber_key" ON "member_import_rows"("importId", "rowNumber");

-- CreateIndex
CREATE INDEX "member_legacy_codes_organizationId_code_idx" ON "member_legacy_codes"("organizationId", "code");

-- CreateIndex
CREATE INDEX "member_legacy_codes_memberId_idx" ON "member_legacy_codes"("memberId");

-- CreateIndex
CREATE UNIQUE INDEX "member_legacy_codes_organizationId_source_code_key" ON "member_legacy_codes"("organizationId", "source", "code");

-- Llaves foráneas con la organización: una fila de una marca no puede apuntar a otra.
ALTER TABLE "member_imports" ADD CONSTRAINT "member_imports_organization_fk" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id");
ALTER TABLE "member_import_rows" ADD CONSTRAINT "member_import_rows_import_fk" FOREIGN KEY ("importId") REFERENCES "member_imports"("id") ON DELETE CASCADE;
ALTER TABLE "member_legacy_codes" ADD CONSTRAINT "member_legacy_codes_member_fk" FOREIGN KEY ("memberId") REFERENCES "members"("id");

ALTER TABLE "member_imports" ADD CONSTRAINT "member_imports_status_chk" CHECK ("status" IN ('REVIEW','APPLIED','CANCELED'));
ALTER TABLE "member_import_rows" ADD CONSTRAINT "member_import_rows_kind_chk" CHECK ("kind" IN ('NEW','MATCH','REVIEW','FILE_DUP','INVALID'));
ALTER TABLE "member_import_rows" ADD CONSTRAINT "member_import_rows_decision_chk" CHECK ("decision" IN ('PENDING','CREATE','MERGE','SKIP'));
-- Una fila aplicada no se vuelve a aplicar ni se cambia su decisión: la aplicación es idempotente por fila.
ALTER TABLE "member_import_rows" ADD CONSTRAINT "member_import_rows_applied_chk" CHECK (("appliedAt" IS NULL) = ("appliedMemberId" IS NULL) OR "decision" = 'SKIP');

-- La aplicación no borra importaciones ni códigos legados: se cancelan.
REVOKE DELETE ON "member_imports" FROM gymflow_app;
REVOKE DELETE ON "member_legacy_codes" FROM gymflow_app;
