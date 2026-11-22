-- DP-03: una factura VIVA por mes y marca. Antes la unicidad contaba también
-- las anuladas, y "anúlala antes de emitir otra" no se podía cumplir.
DROP INDEX IF EXISTS "platform_invoices_organizationId_periodStart_key";
CREATE UNIQUE INDEX "platform_invoices_org_period_live_key" ON "platform_invoices" ("organizationId", "periodStart") WHERE "status" <> 'VOID';
