-- COACH (auditoría 8, fase 2, bloque 2.6; hallazgos 12-02, 12-05, 12-09).
-- Aditiva: nada de lo guardado cambia.
--  · La asignación guarda cuándo toca revisarla («Revisar en» 4, 6 u 8 semanas)
--    y quién la terminó.
--  · Una rutina puede ser la copia personal de un socio («Personalizar para…»):
--    no sale en el catálogo del gimnasio.
--  · `workout_logs`: los días que el socio marca como hechos desde su teléfono
--    («Hoy toca» sale del último). Un día de rutina se marca una vez por fecha.

-- AlterTable
ALTER TABLE "workout_assignments" ADD COLUMN "reviewOn" DATE,
ADD COLUMN "endedByUserId" UUID;

-- AlterTable
ALTER TABLE "workout_templates" ADD COLUMN "personalForMemberId" UUID;

-- CreateTable
CREATE TABLE "workout_logs" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "assignmentId" UUID NOT NULL,
    "dayIndex" INTEGER NOT NULL,
    "doneOn" DATE NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'PORTAL',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "workout_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "workout_logs_organizationId_memberId_doneOn_idx" ON "workout_logs"("organizationId", "memberId", "doneOn");

-- CreateIndex
CREATE UNIQUE INDEX "workout_logs_assignmentId_dayIndex_doneOn_key" ON "workout_logs"("assignmentId", "dayIndex", "doneOn");

-- CreateIndex
CREATE INDEX "workout_templates_organizationId_personalForMemberId_idx" ON "workout_templates"("organizationId", "personalForMemberId");

-- AddForeignKey
ALTER TABLE "workout_logs" ADD CONSTRAINT "workout_logs_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "workout_assignments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "workout_logs" ADD CONSTRAINT "workout_logs_day_chk" CHECK ("dayIndex" BETWEEN 1 AND 7);
ALTER TABLE "workout_logs" ADD CONSTRAINT "workout_logs_source_chk" CHECK ("source" IN ('PORTAL', 'COACH'));
