-- Auditoría 8, fase 1, bloque 1.16 (jobs): corridas de los jobs con candado
-- (28-15). Todo es aditivo.
--
-- `job_runs`: una fila por corrida del cierre diario (DAILY) o del corredor de
-- 15 minutos (FREQUENT). `job_run_steps`: un job en un gimnasio (o de
-- plataforma, organizationId NULL) dentro de una corrida, con la fecha de
-- negocio con la que corrió: así el cierre diario no repite lo que ya corrió
-- hoy y una corrida cortada a medias queda a la vista (RUNNING sin señal de
-- vida → ABANDONED en la siguiente).
CREATE TABLE "job_runs" (
  "id" UUID NOT NULL,
  "runner" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  "startedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "heartbeatAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finishedAt" TIMESTAMPTZ(3),
  "host" TEXT NOT NULL,
  "perfil" TEXT,
  "summary" JSONB,
  "note" TEXT,
  CONSTRAINT "job_runs_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "job_runs_runner_startedAt_idx" ON "job_runs"("runner", "startedAt");
ALTER TABLE "job_runs" ADD CONSTRAINT "job_runs_runner_chk" CHECK ("runner" IN ('DAILY', 'FREQUENT'));
ALTER TABLE "job_runs" ADD CONSTRAINT "job_runs_status_chk" CHECK ("status" IN ('RUNNING', 'OK', 'WITH_ERRORS', 'FAILED', 'ABANDONED'));

-- EL CANDADO: a lo más una corrida RUNNING por corredor. Dos procesos que
-- arranquen a la vez pasan los dos por la consulta previa; solo uno pasa por
-- este índice. El cierre diario y el corredor de 15 minutos son candados
-- distintos: pueden coincidir.
CREATE UNIQUE INDEX "job_runs_running_unique" ON "job_runs"("runner") WHERE "status" = 'RUNNING';

CREATE TABLE "job_run_steps" (
  "id" UUID NOT NULL,
  "runId" UUID NOT NULL,
  "organizationId" UUID,
  "job" TEXT NOT NULL,
  "businessDate" DATE NOT NULL,
  "status" TEXT NOT NULL,
  "startedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finishedAt" TIMESTAMPTZ(3),
  "processed" INTEGER NOT NULL DEFAULT 0,
  "skipped" INTEGER NOT NULL DEFAULT 0,
  "batches" INTEGER NOT NULL DEFAULT 0,
  "truncated" BOOLEAN NOT NULL DEFAULT false,
  "errors" JSONB NOT NULL DEFAULT '[]',
  "error" TEXT,
  CONSTRAINT "job_run_steps_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "job_run_steps_organizationId_job_businessDate_idx" ON "job_run_steps"("organizationId", "job", "businessDate");
CREATE INDEX "job_run_steps_runId_idx" ON "job_run_steps"("runId");
ALTER TABLE "job_run_steps" ADD CONSTRAINT "job_run_steps_runId_fkey" FOREIGN KEY ("runId") REFERENCES "job_runs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "job_run_steps" ADD CONSTRAINT "job_run_steps_status_chk" CHECK ("status" IN ('RUNNING', 'OK', 'WITH_ERRORS', 'FAILED', 'ABANDONED'));
