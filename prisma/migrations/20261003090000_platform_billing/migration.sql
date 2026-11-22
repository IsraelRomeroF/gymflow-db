-- AlterTable
ALTER TABLE "organizations" ADD COLUMN     "billingEmail" TEXT;

-- CreateTable
CREATE TABLE "platform_prices" (
    "moduleKey" TEXT NOT NULL,
    "monthlyCents" BIGINT NOT NULL,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedByUserId" UUID,

    CONSTRAINT "platform_prices_pkey" PRIMARY KEY ("moduleKey")
);

-- CreateTable
CREATE TABLE "platform_invoices" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "folio" TEXT NOT NULL,
    "periodStart" DATE NOT NULL,
    "periodEnd" DATE NOT NULL,
    "lines" JSONB NOT NULL,
    "totalCents" BIGINT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "issuedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dueDate" DATE NOT NULL,
    "paidAt" TIMESTAMPTZ(3),
    "paymentMethod" TEXT,
    "paymentRef" TEXT,
    "note" TEXT,
    "voidReason" TEXT,
    "createdByUserId" UUID,

    CONSTRAINT "platform_invoices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "platform_invoices_folio_key" ON "platform_invoices"("folio");

-- CreateIndex
CREATE INDEX "platform_invoices_organizationId_status_idx" ON "platform_invoices"("organizationId", "status");

-- CreateIndex
CREATE INDEX "platform_invoices_status_dueDate_idx" ON "platform_invoices"("status", "dueDate");

-- CreateIndex
CREATE UNIQUE INDEX "platform_invoices_organizationId_periodStart_key" ON "platform_invoices"("organizationId", "periodStart");

-- AddForeignKey
ALTER TABLE "platform_invoices" ADD CONSTRAINT "platform_invoices_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "platform_invoices" ADD CONSTRAINT "platform_invoices_status_chk"
  CHECK ("status" IN ('PENDING','PAID','VOID'));
ALTER TABLE "platform_invoices" ADD CONSTRAINT "platform_invoices_total_chk" CHECK ("totalCents" >= 0);
ALTER TABLE "platform_prices" ADD CONSTRAINT "platform_prices_cents_chk" CHECK ("monthlyCents" >= 0);
-- Una factura emitida no se borra: se paga o se anula.
REVOKE DELETE ON "platform_invoices" FROM gymflow_app;
