-- Fase 3 · bloque 3.4 · Altas (auditoría 8), D-10: sin la firma del tutor NO se
-- guarda la nota de salud de un menor.
--
-- Las altas digitales que siguen POR REVISAR y son de alguien que hoy tiene
-- menos de 18 años se enviaron cuando el menor aceptaba solo el permiso de
-- datos de salud. Esa nota se borra: al aprobarlas, lo de salud lo autoriza y
-- lo dice su tutor en el mostrador. No toca altas ya aprobadas ni fichas de
-- socios. Se puede correr dos veces sin daño (la segunda no encuentra nada).
UPDATE "member_intakes"
   SET "healthNotes" = NULL
 WHERE "status" = 'SUBMITTED'
   AND "healthNotes" IS NOT NULL
   AND "birthDate" IS NOT NULL
   AND "birthDate" > ((now() AT TIME ZONE 'America/Mexico_City')::date - INTERVAL '18 years');
