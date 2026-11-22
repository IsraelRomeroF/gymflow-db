-- AlterTable
ALTER TABLE "cash_sessions" ADD COLUMN     "countAttempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "firstCountedCashCents" BIGINT;
