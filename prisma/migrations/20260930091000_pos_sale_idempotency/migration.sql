-- AlterTable
ALTER TABLE "pos_sales" ADD COLUMN     "idempotencyKey" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "pos_sales_idempotency_key" ON "pos_sales"("organizationId", "idempotencyKey");
