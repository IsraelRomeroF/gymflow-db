-- Clave de la venta que creó la membresía: reintentar una venta no la duplica (DM-08).
ALTER TABLE "memberships" ADD COLUMN "saleKey" TEXT;
CREATE UNIQUE INDEX "memberships_org_salekey_key" ON "memberships"("organizationId", "saleKey");
