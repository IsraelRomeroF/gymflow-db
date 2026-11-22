-- AlterTable
ALTER TABLE "branches" ADD COLUMN     "publicSlug" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "branches_publicSlug_key" ON "branches"("publicSlug");

-- Solo minúsculas, dígitos y guiones: va en una URL que se comparte por WhatsApp.
ALTER TABLE "branches" ADD CONSTRAINT "branches_public_slug_format_chk"
  CHECK ("publicSlug" IS NULL OR "publicSlug" ~ '^[a-z0-9]+(-[a-z0-9]+)*$');
