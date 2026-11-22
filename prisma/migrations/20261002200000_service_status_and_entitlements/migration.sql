-- AlterTable
ALTER TABLE "organizations" ADD COLUMN     "activatedAt" TIMESTAMPTZ(3),
ADD COLUMN     "serviceStatus" TEXT NOT NULL DEFAULT 'ACTIVE',
ADD COLUMN     "suspendedAt" TIMESTAMPTZ(3),
ADD COLUMN     "suspendedReason" TEXT;

-- CreateTable
CREATE TABLE "organization_entitlements" (
    "organizationId" UUID NOT NULL,
    "moduleKey" TEXT NOT NULL,
    "granted" BOOLEAN NOT NULL,
    "reason" TEXT,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedByUserId" UUID,

    CONSTRAINT "organization_entitlements_pkey" PRIMARY KEY ("organizationId","moduleKey")
);

-- AddForeignKey
ALTER TABLE "organization_entitlements" ADD CONSTRAINT "organization_entitlements_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "organizations" ADD CONSTRAINT "organizations_service_status_chk"
  CHECK ("serviceStatus" IN ('PENDING','ACTIVE','SUSPENDED'));
ALTER TABLE "organization_entitlements" ADD CONSTRAINT "organization_entitlements_key_chk"
  CHECK ("moduleKey" ~ '^[a-z][a-z_]{1,39}$');
-- Lo contratado queda como rastro: no se borra, se marca.
REVOKE DELETE ON "organization_entitlements" FROM gymflow_app;
