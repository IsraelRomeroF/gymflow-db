-- Clases en el plan, a la medida (2026-10-09). Un plan que incluye clases
-- puede incluirlas TODAS (lista vacía) o solo algunas. Y cada tipo de clase
-- dice si se puede incluir en un plan: las que no, siempre se pagan sueltas.
ALTER TABLE "plans" ADD COLUMN "includedClassTypeIds" UUID[] NOT NULL DEFAULT ARRAY[]::UUID[];
ALTER TABLE "class_types" ADD COLUMN "includableInPlans" BOOLEAN NOT NULL DEFAULT true;
