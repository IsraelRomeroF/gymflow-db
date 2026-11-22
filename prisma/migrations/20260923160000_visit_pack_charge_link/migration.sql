-- AlterTable
ALTER TABLE "visit_packs" ADD COLUMN     "chargeId" UUID;

-- CreateIndex
CREATE UNIQUE INDEX "visit_packs_charge_key" ON "visit_packs"("chargeId");

