-- Consola de plataforma (el panel de mayor rango): las acciones críticas
-- piden volver a confirmar con el segundo factor. La confirmación dura unos
-- minutos y vive en la sesión que la hizo, no en el usuario.
ALTER TABLE "sessions" ADD COLUMN "stepUpUntil" TIMESTAMPTZ(3);
