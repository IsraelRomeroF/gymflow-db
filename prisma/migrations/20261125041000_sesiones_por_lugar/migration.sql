-- Auditoría 8, fase 4, bloque 4.1 (D-04, opción a): sesiones por lugar.
--
-- 1) ADITIVO. De qué LUGAR es cada sesión del personal. Se decide una sola
--    vez, al entrar con la contraseña, y no cambia después:
--      · COUNTER      el mostrador (y cualquier otro equipo): 12 horas desde
--                     que se entra, pase lo que pase;
--      · OWNER_PHONE  el teléfono de la dueña: 30 días que se renuevan con el
--                     uso, con un tope desde que entró.
--    Las sesiones que ya existen quedan como COUNTER (el valor por omisión):
--    siguen cerrándose a la hora que se les dijo. Ninguna se alarga.
ALTER TABLE "sessions" ADD COLUMN "kind" TEXT NOT NULL DEFAULT 'COUNTER';
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_kind_check" CHECK ("kind" IN ('COUNTER', 'OWNER_PHONE'));

-- 2) ESCRIBE EN FILAS QUE YA EXISTEN (no es aditivo). El portal del socio
--    pasa de «se cierra a los 7 días sin abrirlo» a «se cierra a los 30 días
--    sin abrirlo». Una sesión del portal que ya llevaba más de 7 días sin uso
--    estaba MUERTA con la regla anterior (el socio habría tenido que pedir un
--    código nuevo); sin este paso, la regla nueva la reviviría, y con ella un
--    teléfono perdido que ya se daba por cerrado. Aquí quedan cerradas de
--    verdad, con su causa escrita.
--      · Toca: member_sessions sin cerrar, sin vencer y con el último uso de
--        hace más de 7 días. Depende del día en que se aplique (cuenta desde
--        ese momento). Correrlo dos veces no cambia nada más: la segunda vez
--        ya no encuentra ninguna.
--      · Para contarlas antes (solo lectura):
--          SELECT count(*) FROM member_sessions
--          WHERE "revokedAt" IS NULL AND "expiresAt" > now() AND "lastSeenAt" <= now() - interval '7 days';
UPDATE "member_sessions"
   SET "revokedAt" = now(), "revokedReason" = 'Sin uso por más de 7 días (regla anterior a D-04)'
 WHERE "revokedAt" IS NULL AND "expiresAt" > now() AND "lastSeenAt" <= now() - interval '7 days';
