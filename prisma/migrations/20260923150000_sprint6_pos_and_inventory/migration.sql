-- CreateEnum
CREATE TYPE "PosSaleStatus" AS ENUM ('COMPLETED', 'VOIDED');

-- CreateEnum
CREATE TYPE "InventoryMovementType" AS ENUM ('PURCHASE', 'SALE', 'SALE_VOIDED', 'ADJUSTMENT', 'TRANSFER_IN', 'TRANSFER_OUT', 'SHRINKAGE');

-- CreateTable
CREATE TABLE "products" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "sku" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "priceCents" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'MXN',
    "tracksInventory" BOOLEAN NOT NULL DEFAULT true,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pos_sales" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "cashSessionId" UUID NOT NULL,
    "memberId" UUID,
    "status" "PosSaleStatus" NOT NULL DEFAULT 'COMPLETED',
    "totalCents" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'MXN',
    "method" "PaymentMethodType",
    "chargeId" UUID,
    "folio" TEXT,
    "voidedByUserId" UUID,
    "voidReason" TEXT,
    "voidedAt" TIMESTAMPTZ(3),
    "soldByUserId" UUID NOT NULL,
    "soldAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,

    CONSTRAINT "pos_sales_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pos_sale_lines" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "posSaleId" UUID NOT NULL,
    "productId" UUID NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unitPriceCents" BIGINT NOT NULL,
    "lineTotalCents" BIGINT NOT NULL,

    CONSTRAINT "pos_sale_lines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_stock" (
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "productId" UUID NOT NULL,
    "quantityOnHand" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "inventory_stock_pkey" PRIMARY KEY ("branchId","productId")
);

-- CreateTable
CREATE TABLE "inventory_movements" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "productId" UUID NOT NULL,
    "movementType" "InventoryMovementType" NOT NULL,
    "quantityDelta" INTEGER NOT NULL,
    "reason" TEXT,
    "posSaleId" UUID,
    "createdByUserId" UUID NOT NULL,
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "businessDate" DATE NOT NULL,

    CONSTRAINT "inventory_movements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "products_organizationId_isActive_idx" ON "products"("organizationId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "products_id_org_key" ON "products"("id", "organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "pos_sales_chargeId_key" ON "pos_sales"("chargeId");

-- CreateIndex
CREATE INDEX "pos_sales_organizationId_branchId_businessDate_idx" ON "pos_sales"("organizationId", "branchId", "businessDate");

-- CreateIndex
CREATE INDEX "pos_sales_cashSessionId_soldAt_idx" ON "pos_sales"("cashSessionId", "soldAt");

-- CreateIndex
CREATE INDEX "pos_sales_organizationId_memberId_soldAt_idx" ON "pos_sales"("organizationId", "memberId", "soldAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "pos_sales_id_org_key" ON "pos_sales"("id", "organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "pos_sales_charge_org_key" ON "pos_sales"("chargeId", "organizationId");

-- CreateIndex
CREATE INDEX "pos_sale_lines_posSaleId_idx" ON "pos_sale_lines"("posSaleId");

-- CreateIndex
CREATE INDEX "pos_sale_lines_organizationId_productId_idx" ON "pos_sale_lines"("organizationId", "productId");

-- CreateIndex
CREATE INDEX "inventory_stock_organizationId_productId_idx" ON "inventory_stock"("organizationId", "productId");

-- CreateIndex
CREATE INDEX "inventory_movements_organizationId_branchId_productId_at_idx" ON "inventory_movements"("organizationId", "branchId", "productId", "at");

-- CreateIndex
CREATE INDEX "inventory_movements_organizationId_businessDate_idx" ON "inventory_movements"("organizationId", "businessDate");

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pos_sales" ADD CONSTRAINT "pos_sales_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pos_sales" ADD CONSTRAINT "pos_sales_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pos_sales" ADD CONSTRAINT "pos_sales_session_same_org_fk" FOREIGN KEY ("cashSessionId", "organizationId") REFERENCES "cash_sessions"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pos_sales" ADD CONSTRAINT "pos_sales_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pos_sales" ADD CONSTRAINT "pos_sales_charge_same_org_fk" FOREIGN KEY ("chargeId", "organizationId") REFERENCES "charges"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pos_sale_lines" ADD CONSTRAINT "pos_lines_sale_same_org_fk" FOREIGN KEY ("posSaleId", "organizationId") REFERENCES "pos_sales"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pos_sale_lines" ADD CONSTRAINT "pos_lines_product_same_org_fk" FOREIGN KEY ("productId", "organizationId") REFERENCES "products"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inventory_stock" ADD CONSTRAINT "stock_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inventory_stock" ADD CONSTRAINT "stock_product_same_org_fk" FOREIGN KEY ("productId", "organizationId") REFERENCES "products"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inv_moves_product_same_org_fk" FOREIGN KEY ("productId", "organizationId") REFERENCES "products"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inv_moves_branch_same_org_fk" FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ════════════════════════════════════════════════════════════════════════════
-- GARANTÍAS QUE PRISMA NO PUEDE EXPRESAR
-- ════════════════════════════════════════════════════════════════════════════

CREATE UNIQUE INDEX "products_org_sku_key"
  ON "products" ("organizationId", "sku")
  WHERE "deletedAt" IS NULL;

CREATE UNIQUE INDEX "pos_sales_org_folio_key"
  ON "pos_sales" ("organizationId", "folio")
  WHERE "folio" IS NOT NULL;

ALTER TABLE "products"
  ADD CONSTRAINT "products_price_non_negative_check" CHECK ("priceCents" >= 0);

-- ── Aritmética de la venta ─────────────────────────────────────────────────
ALTER TABLE "pos_sales"
  ADD CONSTRAINT "pos_sales_total_non_negative_check" CHECK ("totalCents" >= 0);

-- O se cobra ahora, o va a la cuenta del socio. Nunca las dos cosas y nunca
-- ninguna: una venta sin forma de pago y sin cargo es dinero que desaparece.
ALTER TABLE "pos_sales"
  ADD CONSTRAINT "pos_sales_paid_or_charged_check"
  CHECK (("chargeId" IS NULL) = ("method" IS NOT NULL));

-- Cargar a la cuenta exige saber a QUIÉN. No existe la cuenta del público general.
ALTER TABLE "pos_sales"
  ADD CONSTRAINT "pos_sales_on_account_needs_member_check"
  CHECK ("chargeId" IS NULL OR "memberId" IS NOT NULL);

ALTER TABLE "pos_sales"
  ADD CONSTRAINT "pos_sales_void_reason_check"
  CHECK ("status" <> 'VOIDED' OR ("voidReason" IS NOT NULL AND "voidedAt" IS NOT NULL));

ALTER TABLE "pos_sale_lines"
  ADD CONSTRAINT "pos_lines_quantity_positive_check" CHECK ("quantity" > 0);

ALTER TABLE "pos_sale_lines"
  ADD CONSTRAINT "pos_lines_price_non_negative_check" CHECK ("unitPriceCents" >= 0);

-- El total de línea NO se deriva al leer: se congela al vender. Este CHECK
-- garantiza que lo congelado sea aritméticamente cierto.
ALTER TABLE "pos_sale_lines"
  ADD CONSTRAINT "pos_lines_total_composition_check"
  CHECK ("lineTotalCents" = "unitPriceCents" * "quantity");

-- ── Existencias ────────────────────────────────────────────────────────────
-- No se puede vender lo que no hay. Que lo impida el motor y no solo la
-- aplicación es lo que hace que un stock negativo sea imposible, en vez de
-- improbable.
ALTER TABLE "inventory_stock"
  ADD CONSTRAINT "stock_non_negative_check" CHECK ("quantityOnHand" >= 0);

ALTER TABLE "inventory_movements"
  ADD CONSTRAINT "inv_moves_delta_not_zero_check" CHECK ("quantityDelta" <> 0);

ALTER TABLE "inventory_movements"
  ADD CONSTRAINT "inv_moves_sign_coherence_check"
  CHECK (
    ("movementType" IN ('PURCHASE', 'TRANSFER_IN', 'SALE_VOIDED') AND "quantityDelta" > 0)
    OR ("movementType" IN ('SALE', 'TRANSFER_OUT', 'SHRINKAGE') AND "quantityDelta" < 0)
    OR ("movementType" = 'ADJUSTMENT')
  );

-- Las formas de hacer desaparecer producto sin venderlo exigen motivo: es
-- justo donde hay que poder preguntar quién y por qué.
ALTER TABLE "inventory_movements"
  ADD CONSTRAINT "inv_moves_reason_required_check"
  CHECK (
    "movementType" NOT IN ('ADJUSTMENT', 'SHRINKAGE', 'TRANSFER_IN', 'TRANSFER_OUT', 'SALE_VOIDED')
    OR length(btrim(COALESCE("reason", ''))) >= 3
  );

-- ── Append-only ────────────────────────────────────────────────────────────
CREATE TRIGGER inventory_movements_append_only
  BEFORE UPDATE OR DELETE ON "inventory_movements"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER pos_sale_lines_append_only
  BEFORE UPDATE OR DELETE ON "pos_sale_lines"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER pos_sales_no_delete
  BEFORE DELETE ON "pos_sales"
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

-- ── Privilegios ────────────────────────────────────────────────────────────
-- RECORDATORIO: un `GRANT ... ON ALL TABLES` DESHACE los REVOKE anteriores.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO gymflow_app;

REVOKE UPDATE, DELETE ON "audit_logs" FROM gymflow_app;
REVOKE DELETE ON "member_consents" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "visit_ledger_entries" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "membership_events" FROM gymflow_app;
REVOKE DELETE ON "payments" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "payment_allocations" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "charge_adjustments" FROM gymflow_app;
REVOKE DELETE ON "charges" FROM gymflow_app;
REVOKE DELETE ON "billing_cycles" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "cash_movements" FROM gymflow_app;
REVOKE DELETE ON "cash_sessions" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "inventory_movements" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "pos_sale_lines" FROM gymflow_app;
REVOKE DELETE ON "pos_sales" FROM gymflow_app;
