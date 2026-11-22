-- ── Extensiones requeridas por el esquema ───────────────────────────────────
-- Viven en la migración, NO solo en el script de bootstrap: cualquier base
-- creada desde cero (shadow, CI, un entorno nuevo) las necesita.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CreateEnum
CREATE TYPE "AuditActorType" AS ENUM ('USER', 'SYSTEM', 'JOB', 'GATEWAY', 'MEMBER');

-- CreateTable
CREATE TABLE "organizations" (
    "id" UUID NOT NULL,
    "legalName" TEXT NOT NULL,
    "tradeName" TEXT NOT NULL,
    "timezone" TEXT NOT NULL DEFAULT 'America/Mexico_City',
    "defaultCurrency" CHAR(3) NOT NULL DEFAULT 'MXN',
    "settings" JSONB NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "branches" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "addressLine" TEXT,
    "timezone" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "branches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "organizationId" UUID,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phoneE164" TEXT,
    "mfaEnabled" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastLoginAt" TIMESTAMPTZ(3),
    "failedLogins" INTEGER NOT NULL DEFAULT 0,
    "lockedUntil" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" UUID NOT NULL,
    "organizationId" UUID,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "isSystem" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "permissions" (
    "key" TEXT NOT NULL,
    "domain" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "requiresReason" BOOLEAN NOT NULL DEFAULT false,
    "requiresApproval" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "permissions_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "role_permissions" (
    "roleId" UUID NOT NULL,
    "permissionKey" TEXT NOT NULL,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("roleId","permissionKey")
);

-- CreateTable
CREATE TABLE "role_assignments" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "roleId" UUID NOT NULL,
    "branchId" UUID,
    "grantedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "grantedByUserId" UUID,
    "revokedAt" TIMESTAMPTZ(3),

    CONSTRAINT "role_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "role_limit_sets" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "roleId" UUID NOT NULL,
    "maxDiscountPercent" INTEGER,
    "maxWaiverAmountCents" BIGINT,
    "maxManualBalanceAdjustCents" BIGINT,
    "maxCashWithdrawalCents" BIGINT,
    "maxRefundAmountCents" BIGINT,
    "maxManualAccessGrantsPerShift" INTEGER,
    "maxPosVoidsPerShift" INTEGER,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "role_limit_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL,
    "organizationId" UUID,
    "userId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "deviceLabel" TEXT,
    "ip" TEXT,
    "userAgent" TEXT,
    "activeBranchId" UUID,
    "mfaSatisfied" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "revokedAt" TIMESTAMPTZ(3),
    "revokedReason" TEXT,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mfa_factors" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "type" TEXT NOT NULL DEFAULT 'TOTP',
    "secretEncrypted" TEXT NOT NULL,
    "confirmedAt" TIMESTAMPTZ(3),
    "lastUsedCounter" BIGINT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mfa_factors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID,
    "actorUserId" UUID,
    "actorType" "AuditActorType" NOT NULL,
    "action" TEXT NOT NULL,
    "resourceType" TEXT NOT NULL,
    "resourceId" UUID,
    "beforeState" JSONB,
    "afterState" JSONB,
    "reason" TEXT,
    "approvedByUserId" UUID,
    "ip" TEXT,
    "userAgent" TEXT,
    "sessionId" UUID,
    "requestId" TEXT,
    "prevHash" TEXT,
    "hash" TEXT NOT NULL,
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "idempotency_keys" (
    "organizationId" UUID NOT NULL,
    "scope" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "resourceId" UUID,
    "responseHash" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("organizationId","scope","key")
);

-- CreateIndex
CREATE INDEX "branches_organizationId_isActive_idx" ON "branches"("organizationId", "isActive");

-- CreateIndex
CREATE INDEX "users_organizationId_isActive_idx" ON "users"("organizationId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "roles_organizationId_key_key" ON "roles"("organizationId", "key");

-- CreateIndex
CREATE INDEX "permissions_domain_idx" ON "permissions"("domain");

-- CreateIndex
CREATE INDEX "role_assignments_organizationId_userId_revokedAt_idx" ON "role_assignments"("organizationId", "userId", "revokedAt");

-- CreateIndex
CREATE UNIQUE INDEX "role_limit_sets_organizationId_roleId_key" ON "role_limit_sets"("organizationId", "roleId");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_tokenHash_key" ON "sessions"("tokenHash");

-- CreateIndex
CREATE INDEX "sessions_userId_expiresAt_idx" ON "sessions"("userId", "expiresAt");

-- CreateIndex
CREATE INDEX "sessions_expiresAt_idx" ON "sessions"("expiresAt");

-- CreateIndex
CREATE INDEX "mfa_factors_userId_idx" ON "mfa_factors"("userId");

-- CreateIndex
CREATE INDEX "audit_logs_organizationId_at_idx" ON "audit_logs"("organizationId", "at" DESC);

-- CreateIndex
CREATE INDEX "audit_logs_organizationId_resourceType_resourceId_idx" ON "audit_logs"("organizationId", "resourceType", "resourceId");

-- CreateIndex
CREATE INDEX "audit_logs_organizationId_actorUserId_businessDate_idx" ON "audit_logs"("organizationId", "actorUserId", "businessDate");

-- CreateIndex
CREATE INDEX "idempotency_keys_expiresAt_idx" ON "idempotency_keys"("expiresAt");

-- AddForeignKey
ALTER TABLE "branches" ADD CONSTRAINT "branches_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "roles" ADD CONSTRAINT "roles_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_permissionKey_fkey" FOREIGN KEY ("permissionKey") REFERENCES "permissions"("key") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_assignments" ADD CONSTRAINT "role_assignments_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_assignments" ADD CONSTRAINT "role_assignments_grantedByUserId_fkey" FOREIGN KEY ("grantedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_assignments" ADD CONSTRAINT "role_assignments_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_assignments" ADD CONSTRAINT "role_assignments_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "branches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_limit_sets" ADD CONSTRAINT "role_limit_sets_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_limit_sets" ADD CONSTRAINT "role_limit_sets_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mfa_factors" ADD CONSTRAINT "mfa_factors_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================================
-- Garantías estructurales que Prisma no expresa de forma declarativa.
-- NO son opcionales: sin ellas el modelo pierde sus invariantes.
-- Referencias: ADR-001 (tenancy), ADR-018 (auditoría), docs/05-modelo-datos.md
-- ============================================================================

-- ── 1. Índices únicos PARCIALES ─────────────────────────────────────────────
-- Permiten reutilizar un código o un correo tras una baja lógica.

CREATE UNIQUE INDEX "branches_org_code_active_key"
  ON "branches" ("organizationId", "code")
  WHERE "deletedAt" IS NULL;

CREATE UNIQUE INDEX "users_org_email_active_key"
  ON "users" ("organizationId", lower("email"))
  WHERE "deletedAt" IS NULL;

-- El superadmin de plataforma no tiene organización: su correo es único global.
CREATE UNIQUE INDEX "users_platform_email_active_key"
  ON "users" (lower("email"))
  WHERE "deletedAt" IS NULL AND "organizationId" IS NULL;

-- Evita duplicar la misma concesión. COALESCE porque NULL no compara en UNIQUE.
CREATE UNIQUE INDEX "role_assignments_unique_active"
  ON "role_assignments" ("userId", "roleId", COALESCE("branchId", '00000000-0000-0000-0000-000000000000'::uuid))
  WHERE "revokedAt" IS NULL;

-- ── 2. FKs COMPUESTAS que cruzan el tenant ──────────────────────────────────
-- Control nº3 de ADR-001. Se declaran en schema.prisma (relaciones con
-- `fields: [x, organizationId]`), NO aquí: si viven solo en SQL crudo,
-- Prisma las trata como deriva e intenta borrarlas en cada migración.

-- ── 3. Coherencia de roles ──────────────────────────────────────────────────
-- Un rol de sistema (organizationId NULL) no puede declararse no-de-sistema,
-- y viceversa: evita roles huérfanos que nadie sabe a quién pertenecen.
ALTER TABLE "roles"
  ADD CONSTRAINT "roles_system_consistency_chk"
  CHECK (("organizationId" IS NULL AND "isSystem") OR ("organizationId" IS NOT NULL AND NOT "isSystem"));

-- ── 4. Bitácora append-only ─────────────────────────────────────────────────
-- El hash encadenado detecta manipulación; el trigger la IMPIDE.
-- Defensa en profundidad: el REVOKE cubre al rol de aplicación, el trigger
-- cubre también a quien se conecte como propietario.

CREATE OR REPLACE FUNCTION gymflow_audit_is_append_only()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs es append-only: % no está permitido', TG_OP
    USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE TRIGGER "audit_logs_no_update"
  BEFORE UPDATE ON "audit_logs"
  FOR EACH ROW EXECUTE FUNCTION gymflow_audit_is_append_only();

CREATE TRIGGER "audit_logs_no_delete"
  BEFORE DELETE ON "audit_logs"
  FOR EACH ROW EXECUTE FUNCTION gymflow_audit_is_append_only();

-- ── 5. Privilegios del rol de aplicación ────────────────────────────────────
-- gymflow_app NO es propietario. Recibe solo DML, y se le REVOCA el borrado
-- sobre la bitácora. Cuando lleguen las tablas del libro financiero
-- (Sprint 4) se les aplicará el mismo tratamiento.

GRANT USAGE ON SCHEMA public TO gymflow_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO gymflow_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO gymflow_app;

REVOKE UPDATE, DELETE ON "audit_logs" FROM gymflow_app;

-- Que los privilegios apliquen también a lo que se cree en migraciones futuras.
ALTER DEFAULT PRIVILEGES FOR ROLE gymflow_owner IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO gymflow_app;
ALTER DEFAULT PRIVILEGES FOR ROLE gymflow_owner IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO gymflow_app;
