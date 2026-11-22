-- AlterTable
ALTER TABLE "branches" ADD COLUMN     "rosterVersion" BIGINT NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "member_credentials" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "kind" "CredentialKind" NOT NULL,
    "secretEncrypted" TEXT,
    "pinHash" TEXT,
    "rfidCardId" TEXT,
    "lastUsedCounter" INTEGER,
    "revokedAt" TIMESTAMPTZ(3),
    "revokedReason" TEXT,
    "issuedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "member_credentials_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "member_credentials_organizationId_memberId_idx" ON "member_credentials"("organizationId", "memberId");

-- CreateIndex
CREATE UNIQUE INDEX "member_credentials_id_org_key" ON "member_credentials"("id", "organizationId");

-- AddForeignKey
ALTER TABLE "member_credentials" ADD CONSTRAINT "credentials_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_credentials" ADD CONSTRAINT "member_credentials_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ════════════════════════════════════════════════════════════════════════════
-- GARANTÍAS QUE PRISMA NO PUEDE EXPRESAR
-- ════════════════════════════════════════════════════════════════════════════

-- Una credencial VIVA por tipo y socio: dos QR activos a la vez significarían
-- que el socio puede prestar uno y seguir entrando con el otro.
CREATE UNIQUE INDEX "credentials_one_live_per_kind"
  ON "member_credentials" ("memberId", "kind")
  WHERE "revokedAt" IS NULL;

-- Una tarjeta física no puede estar asignada a dos socios.
CREATE UNIQUE INDEX "credentials_rfid_unique"
  ON "member_credentials" ("organizationId", "rfidCardId")
  WHERE "rfidCardId" IS NOT NULL AND "revokedAt" IS NULL;

-- Revocar exige motivo: "se revocó" sin más no permite reconstruir por qué un
-- socio se quedó fuera, y esa es justamente la reclamación que llega.
ALTER TABLE "member_credentials"
  ADD CONSTRAINT "credentials_revoke_reason_check"
  CHECK (("revokedAt" IS NULL) = ("revokedReason" IS NULL));

-- Una credencial de QR sin secreto no puede validarse sin red, que es su
-- única razón de existir.
ALTER TABLE "member_credentials"
  ADD CONSTRAINT "credentials_qr_needs_secret_check"
  CHECK ("kind" <> 'QR' OR "secretEncrypted" IS NOT NULL);

ALTER TABLE "member_credentials"
  ADD CONSTRAINT "credentials_pin_needs_hash_check"
  CHECK ("kind" <> 'PIN' OR "pinHash" IS NOT NULL);

ALTER TABLE "member_credentials"
  ADD CONSTRAINT "credentials_rfid_needs_card_check"
  CHECK ("kind" <> 'RFID' OR "rfidCardId" IS NOT NULL);

-- La versión del padrón SOLO sube. Un retroceso permitiría reproducir un
-- padrón antiguo en el que un socio expulsado todavía figuraba.
ALTER TABLE "branches"
  ADD CONSTRAINT "branches_roster_version_check"
  CHECK ("rosterVersion" >= 0);

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
