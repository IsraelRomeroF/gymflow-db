-- CONSERVACIÓN CON LA BAJA CALCULADA (auditoría 8, fase 4, bloque 4.18; P-01,
-- respuesta de Israel del 2026-11-25).
--
-- Desde aquí la conservación (el rostro a los 30 días de la baja y la lista
-- mensual por anonimizar) cuenta también la baja de D-18: canceló su
-- membresía, o la tiene terminada el plazo del gimnasio sin renovar, salvo
-- que siga viniendo sin membresía. La regla vive en el núcleo
-- (`bajaParaConservar`) y la aplica el cierre diario (`privacy.conservation`).
--
-- QUÉ FILAS TOCA: ninguna se borra ni se reescribe. La tabla nueva nace
-- vacía. La columna nueva de `privacy_batch_items` se agrega con valor por
-- omisión 'ARCHIVED', así que TODOS los renglones que ya existen quedan con
-- 'ARCHIVED' (y es lo cierto: hasta hoy solo entraba a la lista quien había
-- sido dado de baja en su ficha). No depende del día en que se aplique.
-- Para contarlos antes (solo lee):
--   SELECT count(*) FROM "privacy_batch_items";

-- ── El arranque de la baja calculada en cada gimnasio (arranque suave) ──────
-- La escribe la primera pasada del cierre diario con el código de 4.18. A
-- quien ESE DÍA ya era baja calculada, los 30 días del rostro le cuentan desde
-- aquí: la primera noche no se borra ningún rostro. Una fila por gimnasio, que
-- no se mueve ni se borra (como `privacy_conservation_starts`, de 3.9).
CREATE TABLE "privacy_calculated_baja_starts" (
  "organizationId" UUID NOT NULL,
  "startedOn" DATE NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "privacy_calculated_baja_starts_pkey" PRIMARY KEY ("organizationId")
);
ALTER TABLE "privacy_calculated_baja_starts" ADD CONSTRAINT "privacy_calculated_baja_starts_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT ON "privacy_calculated_baja_starts" TO gymflow_app;
REVOKE UPDATE, DELETE ON "privacy_calculated_baja_starts" FROM gymflow_app;

-- ── De qué baja entró cada exsocio a la lista ───────────────────────────────
-- ARCHIVED: lo dieron de baja en su ficha (como hasta hoy); CANCELED / EXPIRED:
-- la baja calculada. Para esos, `archivedAt` guarda la medianoche UTC del día
-- de su baja (`archivedOn`): no hubo un acto con hora.
ALTER TABLE "privacy_batch_items" ADD COLUMN "bajaCause" TEXT NOT NULL DEFAULT 'ARCHIVED';
ALTER TABLE "privacy_batch_items" ADD CONSTRAINT "privacy_batch_items_baja_cause_chk" CHECK ("bajaCause" IN ('ARCHIVED', 'CANCELED', 'EXPIRED'));
