-- DropIndex
DROP INDEX "payments_reversesPaymentId_idx";

-- AlterTable
ALTER TABLE "pos_sales" ADD COLUMN     "externalRef" TEXT;
