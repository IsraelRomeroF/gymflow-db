-- AlterTable
ALTER TABLE "organizations" ADD COLUMN     "platformPlanId" UUID;

-- CreateTable
CREATE TABLE "platform_plans" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "modules" JSONB NOT NULL DEFAULT '[]',
    "monthlyCents" BIGINT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "platform_plans_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_platformPlanId_fkey" FOREIGN KEY ("platformPlanId") REFERENCES "platform_plans"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Un precio nunca es negativo; la aplicación no borra planes (se desactivan).
ALTER TABLE "platform_plans" ADD CONSTRAINT "platform_plans_monthly_nonneg_chk" CHECK ("monthlyCents" IS NULL OR "monthlyCents" >= 0);
REVOKE DELETE ON "platform_plans" FROM gymflow_app;
