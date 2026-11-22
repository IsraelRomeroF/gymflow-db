-- 5-24 (auditoría 8, fase 0): el consumo de visita se liga a la ASISTENCIA,
-- como dice su columna. Hasta hoy guardaba el id de la DECISIÓN: funcionaba
-- porque no hay llave foránea, pero la que anuncia el esquema habría tumbado
-- toda entrada con paquete, y el libro de visitas no se podía unir con las
-- asistencias. Se corrigen las filas viejas: una decisión tiene a lo más una
-- asistencia (`attendance_decision_key`). La llave foránea queda para después.
-- El libro es append-only por trigger: se apaga solo para este relleno único.
ALTER TABLE "visit_ledger_entries" DISABLE TRIGGER "visit_ledger_no_update";
UPDATE "visit_ledger_entries" v SET "attendanceEventId" = ae.id
FROM "attendance_events" ae
WHERE ae."accessDecisionId" = v."attendanceEventId"
  AND ae."organizationId" = v."organizationId"
  AND NOT EXISTS (
    SELECT 1 FROM "visit_ledger_entries" o
    WHERE o."visitPackId" = v."visitPackId" AND o."attendanceEventId" = ae.id
  );
ALTER TABLE "visit_ledger_entries" ENABLE TRIGGER "visit_ledger_no_update";
