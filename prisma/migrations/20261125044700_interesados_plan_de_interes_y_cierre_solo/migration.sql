-- INTERESADOS (auditoría 8, fase 4, bloque 4.7; decisión D-31).
-- Aditiva: dos columnas nuevas que nacen vacías y una tabla nueva. No escribe
-- en ninguna fila que ya exista y no depende del día en que se aplique.
--
--  · Se anota el PLAN QUE PREGUNTÓ el interesado: la venta abre con él.
--  · Un interesado abierto se CIERRA SOLO a los 60 días sin contacto ni fecha
--    pendiente, y se puede reabrir: la reapertura se guarda para que el plazo
--    vuelva a contar desde ella (si no, se cerraría otra vez esa noche).
--  · El cierre solo no empieza de golpe: la primera corrida del job
--    `prospects.auto-close` en un gimnasio solo guarda aquí DESDE QUÉ DÍA
--    cierra (una semana después), y mientras el panel dice cuántos serían.
--
-- Esta migración NO cierra a nadie. Quién se cerraría lo cuenta, sin escribir,
-- `gymflow-backend/scripts/interesados-cierre-previo.ts`.

ALTER TABLE "prospects"
  ADD COLUMN "interestPlanId" UUID,
  ADD COLUMN "reopenedAt" TIMESTAMPTZ(3);

-- Si un plan se borrara de verdad (hoy solo se archivan), el interesado se queda sin plan anotado.
ALTER TABLE "prospects" ADD CONSTRAINT "prospects_interestPlanId_fkey"
  FOREIGN KEY ("interestPlanId") REFERENCES "plans"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "prospects_interest_plan_idx" ON "prospects"("interestPlanId");

-- Desde qué día cierra solo cada gimnasio. Sin fila: todavía no cierra a nadie.
CREATE TABLE "prospect_auto_close_starts" (
    "organizationId" UUID NOT NULL,
    "startsOn" DATE NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "prospect_auto_close_starts_pkey" PRIMARY KEY ("organizationId")
);
ALTER TABLE "prospect_auto_close_starts" ADD CONSTRAINT "prospect_auto_close_starts_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
