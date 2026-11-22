-- CreateTable
CREATE TABLE "branch_module_overrides" (
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "moduleKey" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL,
    "reason" TEXT,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedByUserId" UUID,

    CONSTRAINT "branch_module_overrides_pkey" PRIMARY KEY ("branchId","moduleKey")
);

-- CreateIndex
CREATE INDEX "branch_module_overrides_organizationId_idx" ON "branch_module_overrides"("organizationId");

-- AddForeignKey
ALTER TABLE "branch_module_overrides" ADD CONSTRAINT "branch_module_overrides_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "branch_module_overrides" ADD CONSTRAINT "branch_module_overrides_key_chk"
  CHECK ("moduleKey" ~ '^[a-z][a-z_]{1,39}$');
-- Como en organization_modules: apagar no borra, queda el rastro.
REVOKE DELETE ON "branch_module_overrides" FROM gymflow_app;
