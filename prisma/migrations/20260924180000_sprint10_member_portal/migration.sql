-- CreateTable
CREATE TABLE "portal_invites" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "codeHash" TEXT NOT NULL,
    "issuedByUserId" UUID,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "usedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "portal_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_sessions" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "deviceLabel" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "revokedAt" TIMESTAMPTZ(3),
    "revokedReason" TEXT,

    CONSTRAINT "member_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "portal_invites_codeHash_key" ON "portal_invites"("codeHash");

-- CreateIndex
CREATE INDEX "portal_invites_organizationId_expiresAt_idx" ON "portal_invites"("organizationId", "expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "member_sessions_tokenHash_key" ON "member_sessions"("tokenHash");

-- CreateIndex
CREATE INDEX "member_sessions_memberId_expiresAt_idx" ON "member_sessions"("memberId", "expiresAt");

-- CreateIndex
CREATE INDEX "member_sessions_expiresAt_idx" ON "member_sessions"("expiresAt");

-- AddForeignKey
ALTER TABLE "portal_invites" ADD CONSTRAINT "invites_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "portal_invites" ADD CONSTRAINT "portal_invites_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_sessions" ADD CONSTRAINT "member_sessions_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_sessions" ADD CONSTRAINT "member_sessions_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ════════════════════════════════════════════════════════════════════════════
-- GARANTÍAS QUE PRISMA NO PUEDE EXPRESAR
-- ════════════════════════════════════════════════════════════════════════════

-- Una invitación VIVA por socio. Dos códigos válidos a la vez significan que
-- uno anda suelto sin que nadie lo sepa, y ese es exactamente el que se usa.
CREATE UNIQUE INDEX "portal_invites_one_live_per_member"
  ON "portal_invites" ("memberId")
  WHERE "usedAt" IS NULL;

ALTER TABLE "member_sessions"
  ADD CONSTRAINT "member_sessions_revoke_reason_check"
  CHECK (("revokedAt" IS NULL) = ("revokedReason" IS NULL));

-- Una sesión que expira antes de crearse no es una sesión.
ALTER TABLE "member_sessions"
  ADD CONSTRAINT "member_sessions_expiry_check"
  CHECK ("expiresAt" > "createdAt");

ALTER TABLE "portal_invites"
  ADD CONSTRAINT "portal_invites_expiry_check"
  CHECK ("expiresAt" > "createdAt");

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
