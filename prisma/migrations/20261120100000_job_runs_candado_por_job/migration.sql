-- Auditoría 8, fase 1, bloque 1.16 (jobs). Aditivo.
--
-- EL CANDADO POR JOB. El cierre diario y el corredor de 15 minutos tienen
-- candados distintos (`job_runs_running_unique`) y pueden coincidir; los jobs
-- frecuentes corren en los dos. Este índice impide que el MISMO job corra a la
-- vez para el MISMO gimnasio desde dos corridas: el segundo que intente
-- abrir el paso recibe la violación de unicidad y lo omite. Los jobs de
-- plataforma (organizationId NULL) comparten un mismo lugar en el índice.
CREATE UNIQUE INDEX "job_run_steps_running_unique"
  ON "job_run_steps"("job", COALESCE("organizationId", '00000000-0000-0000-0000-000000000000'::uuid))
  WHERE "status" = 'RUNNING';
