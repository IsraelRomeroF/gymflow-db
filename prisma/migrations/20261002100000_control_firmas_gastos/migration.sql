-- AlterTable
ALTER TABLE "approval_grants" ADD COLUMN     "amountCents" BIGINT,
ADD COLUMN     "branchId" UUID,
ADD COLUMN     "resourceId" UUID,
ADD COLUMN     "resourceType" TEXT,
ADD COLUMN     "selfApproved" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "mustChangePassword" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "passwordResetAt" TIMESTAMPTZ(3),
ADD COLUMN     "passwordResetByUserId" UUID;

-- CreateTable
CREATE TABLE "operating_expenses" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID,
    "category" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "amountCents" BIGINT NOT NULL,
    "periodMonth" DATE NOT NULL,
    "createdByUserId" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "voidedAt" TIMESTAMPTZ(3),
    "voidedByUserId" UUID,
    "voidReason" TEXT,

    CONSTRAINT "operating_expenses_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "operating_expenses_organizationId_periodMonth_idx" ON "operating_expenses"("organizationId", "periodMonth");

-- Un gasto es dinero: no se borra, se anula con motivo.
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_amount_chk" CHECK ("amountCents" > 0);
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_month_chk" CHECK (EXTRACT(DAY FROM "periodMonth") = 1);
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_category_chk"
  CHECK ("category" IN ('RENT','PAYROLL','UTILITIES','SERVICES','MAINTENANCE','MARKETING','TAXES','OTHER'));
REVOKE DELETE ON "operating_expenses" FROM gymflow_app;
