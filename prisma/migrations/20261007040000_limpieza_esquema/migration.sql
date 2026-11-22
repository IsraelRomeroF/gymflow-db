-- DropIndex
DROP INDEX "permissions_domain_idx";

-- AlterTable
ALTER TABLE "access_gateways" DROP COLUMN "certificateFingerprint";

-- AlterTable
ALTER TABLE "chargebacks" DROP COLUMN "evidenceObjectKey";

-- AlterTable
ALTER TABLE "member_consents" DROP COLUMN "evidenceObjectKey";

-- AlterTable
ALTER TABLE "plans" DROP COLUMN "visitsPerPeriodAtNonHomeBranch";

-- DropTable
DROP TABLE "idempotency_keys";
