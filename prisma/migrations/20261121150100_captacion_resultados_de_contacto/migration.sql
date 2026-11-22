-- CAPTACIÓN (auditoría 8, fase 2, bloque 2.4; hallazgo 10-05).
-- Dos resultados de contacto nuevos, solo para interesados: «Vino a probar»
-- (TRIAL_VISIT) y «Se le mandó el alta digital» (INTAKE_SENT). La columna es
-- texto con CHECK: se sustituye la lista. Aditiva: lo ya guardado sigue valiendo.
-- (Va aparte de 20261121150000 porque esa ya estaba aplicada en la base del
-- bloque cuando se vio la restricción.)

ALTER TABLE "follow_ups" DROP CONSTRAINT "follow_ups_outcome_check";
ALTER TABLE "follow_ups" ADD CONSTRAINT "follow_ups_outcome_check"
  CHECK ("outcome" IN ('ANSWERED', 'NO_ANSWER', 'INTERESTED', 'NOT_INTERESTED', 'COMING_BACK', 'TRIAL_VISIT', 'INTAKE_SENT'));
