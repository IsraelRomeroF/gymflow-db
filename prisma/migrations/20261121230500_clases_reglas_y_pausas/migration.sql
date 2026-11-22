-- CLASES (auditoría 8, fase 2, bloque 2.5; hallazgos 11-05 y 11-08).
-- Aditiva y segura con datos reales: dos tablas nuevas y una columna opcional.
--
--  · `class_settings`: las reglas de reserva que fija cada gimnasio. Sin fila,
--    valen las de fábrica (las que el producto traía escritas en código), así
--    que ningún gimnasio cambia de comportamiento al aplicar esto.
--  · `class_pauses`: pausas del horario por fechas («del 22 dic al 2 ene»).
--  · `class_schedules.pauseId`: qué pausa canceló una sesión, para devolverla
--    si la pausa se quita antes de que empiece.

CREATE TABLE "class_settings" (
    "organizationId" UUID NOT NULL,
    "maxDaysAhead" SMALLINT NOT NULL,
    "cancelCutoffMinutes" INTEGER NOT NULL,
    "noShowWindowDays" SMALLINT NOT NULL,
    "noShowsBeforeBlock" SMALLINT NOT NULL,
    "blockDays" SMALLINT NOT NULL,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "updatedByUserId" UUID,

    CONSTRAINT "class_settings_pkey" PRIMARY KEY ("organizationId"),
    -- Los mismos rangos que `BOOKING_RULE_LIMITS` del núcleo.
    CONSTRAINT "class_settings_rangos_chk" CHECK (
      "maxDaysAhead" BETWEEN 1 AND 21
      AND "cancelCutoffMinutes" BETWEEN 0 AND 2880
      AND "noShowWindowDays" BETWEEN 7 AND 90
      AND "noShowsBeforeBlock" BETWEEN 1 AND 10
      AND "blockDays" BETWEEN 1 AND 60
    )
);
ALTER TABLE "class_settings" ADD CONSTRAINT "class_settings_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "class_pauses" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID,
    "fromDate" DATE NOT NULL,
    "toDate" DATE NOT NULL,
    "reason" TEXT NOT NULL,
    "createdByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMPTZ(3),
    "endedByUserId" UUID,

    CONSTRAINT "class_pauses_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "class_pauses_fechas_chk" CHECK ("toDate" >= "fromDate")
);
CREATE INDEX "class_pauses_organizationId_toDate_idx" ON "class_pauses"("organizationId", "toDate");
ALTER TABLE "class_pauses" ADD CONSTRAINT "class_pauses_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "class_pauses" ADD CONSTRAINT "class_pauses_branch_same_org_fk"
  FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "class_schedules" ADD COLUMN "pauseId" UUID;
