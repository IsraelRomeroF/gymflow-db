-- DM-10: cada movimiento de caja lleva su propio día de negocio.
-- Lo histórico hereda el del turno: es lo que se venía informando. La tabla
-- es append-only por trigger; se apaga solo para este relleno único.
ALTER TABLE "cash_movements" ADD COLUMN IF NOT EXISTS "businessDate" DATE;
ALTER TABLE "cash_movements" DISABLE TRIGGER cash_movements_append_only;
UPDATE "cash_movements" m SET "businessDate" = cs."businessDate"
  FROM "cash_sessions" cs WHERE cs."id" = m."cashSessionId" AND m."businessDate" IS NULL;
ALTER TABLE "cash_movements" ENABLE TRIGGER cash_movements_append_only;
ALTER TABLE "cash_movements" ALTER COLUMN "businessDate" SET NOT NULL;
CREATE INDEX IF NOT EXISTS "cash_movements_org_business_date_idx" ON "cash_movements" ("organizationId", "businessDate");
