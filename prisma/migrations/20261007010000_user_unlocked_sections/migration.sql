-- Secciones de Dirección y Cumplimiento liberadas por el dueño a cada persona.
ALTER TABLE "users" ADD COLUMN "unlockedSections" JSONB NOT NULL DEFAULT '[]';
