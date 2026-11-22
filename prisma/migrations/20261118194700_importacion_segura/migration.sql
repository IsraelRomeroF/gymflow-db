-- Bloque 0.11 · Importación segura antes de migrar el padrón real
-- (Auditoría 8, hallazgos 18-01 y 18-02). Solo agrega: ninguna columna se
-- quita ni cambia de tipo, y lo que se rellena sale de datos que ya existen.

-- 1) UN SALDO INICIAL POR SOCIO Y POR REGISTRO DEL SISTEMA ANTERIOR (D18-01,
--    docs/09 §5). Cada fila aplicada guarda el saldo que DE VERDAD cargó;
--    reimportar el archivo corregido lo consulta y no vuelve a cargar el mismo
--    saldo. Antes de esta migración toda fila aplicada con saldo lo cargaba
--    (cargo OPENING_BALANCE o nota de crédito, en la misma transacción que la
--    marcaba aplicada): se rellenan con él.
ALTER TABLE "member_import_rows" ADD COLUMN "balanceLoadedCents" BIGINT;
UPDATE "member_import_rows"
   SET "balanceLoadedCents" = "balanceCents"
 WHERE "appliedAt" IS NOT NULL AND "decision" <> 'SKIP'
   AND "balanceCents" IS NOT NULL AND "balanceCents" <> 0;
ALTER TABLE "member_import_rows" ADD CONSTRAINT "member_import_rows_balance_loaded_chk"
  CHECK ("balanceLoadedCents" IS NULL OR ("balanceLoadedCents" <> 0 AND "appliedAt" IS NOT NULL));
CREATE INDEX "member_import_rows_organizationId_appliedMemberId_idx" ON "member_import_rows"("organizationId", "appliedMemberId");

-- 2) DATOS DUDOSOS (D18-02): saldo, vigencia o fecha de alta que venían en el
--    archivo y no se entendieron. La fila espera a que una persona decida:
--    entra sin ese dato (WITHOUT), con el valor que escribió (FIXED) o se omite.
ALTER TABLE "member_import_rows" ADD COLUMN "doubtful" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "member_import_rows" ADD COLUMN "dataStatus" TEXT;
ALTER TABLE "member_import_rows" ADD COLUMN "dataDecidedByUserId" UUID;
ALTER TABLE "member_import_rows" ADD COLUMN "dataDecidedAt" TIMESTAMPTZ(3);
ALTER TABLE "member_import_rows" ADD CONSTRAINT "member_import_rows_data_status_chk"
  CHECK ("dataStatus" IN ('PENDING', 'WITHOUT', 'FIXED'));

-- Las importaciones que siguen EN REVISIÓN se prepararon con la regla vieja:
-- sus filas sin aplicar con un saldo o una fecha ilegible pasan a esperar
-- decisión, igual que las nuevas. Se reconocen por el texto del problema que
-- ya guardaba la limpieza (gymflow-core/src/import.ts).
UPDATE "member_import_rows" AS r
   SET "doubtful" = d.arr, "dataStatus" = 'PENDING'
  FROM (
    SELECT r2."id",
           jsonb_agg(jsonb_build_object('field', x.field, 'value', regexp_replace(x.p, '^[^:]*: ', ''), 'problem', x.p)) AS arr
      FROM "member_import_rows" r2
      JOIN "member_imports" i ON i."id" = r2."importId" AND i."status" = 'REVIEW'
     CROSS JOIN LATERAL (
       SELECT p, CASE
                   WHEN p LIKE 'Saldo no se entiende: %' THEN 'balance'
                   WHEN p LIKE 'Vigencia no se entiende: %' THEN 'periodEnd'
                   WHEN p LIKE 'Fecha de alta no se entiende: %' OR p LIKE 'Fecha de alta en el futuro: %' THEN 'joinedAt'
                 END AS field
         FROM jsonb_array_elements_text(r2."problems") AS p
     ) x
     WHERE r2."appliedAt" IS NULL AND r2."kind" <> 'INVALID' AND x.field IS NOT NULL
     GROUP BY r2."id"
  ) d
 WHERE r."id" = d."id";
