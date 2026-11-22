-- La dueña ya no firma (solo consulta): desaparece la firma propia de "una sola dueña".
-- AlterTable
ALTER TABLE "approval_grants" DROP COLUMN "selfApproved";
