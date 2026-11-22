-- CreateTable
CREATE TABLE "organization_modules" (
    "organizationId" UUID NOT NULL,
    "moduleKey" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedByUserId" UUID,

    CONSTRAINT "organization_modules_pkey" PRIMARY KEY ("organizationId","moduleKey")
);

-- AddForeignKey
ALTER TABLE "organization_modules" ADD CONSTRAINT "organization_modules_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- La clave es la del catálogo de @gymflow/core: minúsculas y guion bajo.
ALTER TABLE "organization_modules" ADD CONSTRAINT "organization_modules_key_chk"
  CHECK ("moduleKey" ~ '^[a-z][a-z_]{1,39}$');
-- Apagar no borra: la fila queda como rastro y se vuelve a encender.
REVOKE DELETE ON "organization_modules" FROM gymflow_app;
