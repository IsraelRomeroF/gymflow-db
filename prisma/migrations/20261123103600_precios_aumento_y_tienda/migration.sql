-- PRECIOS Y TIENDA (auditoría 8, fase 3, bloque 3.6; decisiones D-19 y D-21).
-- Aditiva, salvo la marca inicial de «conserva su precio» (ver abajo).

-- ── D-19 · Subir el precio de un plan le sube a todos en su siguiente pago ──
-- El precio pactado (`agreedPriceCents`) sigue siendo lo que se cobra en cada
-- cuota, pero ya no protege a nadie por sí solo: al cambiar el precio de un
-- plan, la aplicación mueve el pactado de sus membresías vivas en la misma
-- transacción. Solo conserva su precio la que tenga esta marca.
ALTER TABLE "memberships" ADD COLUMN "priceProtected" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "memberships" ADD COLUMN "priceProtectedReason" TEXT;
-- Una marca sin precio escrito no protege nada.
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_price_protected_chk"
  CHECK (NOT "priceProtected" OR "agreedPriceCents" IS NOT NULL);

-- Lo que YA estaba pactado a un precio distinto del de lista (importados con
-- su precio, convenios, descuentos al vender) nace marcado: no cambia solo.
-- Al subir un precio, la pantalla dice cuántos son y alguien decide si
-- también les sube; esa decisión queda en la bitácora. Quien paga hoy
-- exactamente el precio de lista de su sede no se marca: sigue al plan.
UPDATE "memberships" ms
   SET "priceProtected" = true,
       "priceProtectedReason" = 'Ya tenía un precio distinto al de lista cuando los aumentos empezaron a aplicar a todos'
  FROM "plans" p
 WHERE p."id" = ms."planId"
   AND ms."status" NOT IN ('CANCELED', 'EXPIRED')
   AND ms."priceProtected" = false
   AND ms."agreedPriceCents" IS NOT NULL
   AND ms."agreedPriceCents" <> COALESCE(
         (SELECT a."priceOverrideCents" FROM "plan_branch_availability" a
           WHERE a."planId" = ms."planId" AND a."branchId" = ms."soldAtBranchId"),
         p."priceCents");

-- El acto: quién cambió qué precio, de cuánto a cuánto y a cuántos tocó.
CREATE TABLE "plan_price_changes" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "planId" UUID NOT NULL,
  "fromPriceCents" BIGINT NOT NULL,
  "toPriceCents" BIGINT NOT NULL,
  -- ¿Se decidió subirles también a quienes conservaban su precio?
  "includedProtected" BOOLEAN NOT NULL DEFAULT false,
  "touchedCount" INTEGER NOT NULL DEFAULT 0,
  "protectedKeptCount" INTEGER NOT NULL DEFAULT 0,
  "reason" TEXT NOT NULL,
  "createdByUserId" UUID,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "plan_price_changes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "plan_price_changes_precios_chk" CHECK ("fromPriceCents" >= 0 AND "toPriceCents" >= 0 AND "fromPriceCents" <> "toPriceCents")
);
CREATE INDEX "plan_price_changes_org_plan_idx" ON "plan_price_changes"("organizationId", "planId", "createdAt");
ALTER TABLE "plan_price_changes" ADD CONSTRAINT "plan_price_changes_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "plan_price_changes" ADD CONSTRAINT "plan_price_changes_plan_same_org_fk" FOREIGN KEY ("planId", "organizationId") REFERENCES "plans"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- A quién le cambió y de cuánto a cuánto: de aquí salen el aviso al teléfono
-- (bandeja de salida) y la línea del recibo. Es historia: no se edita.
CREATE TABLE "membership_price_changes" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "planPriceChangeId" UUID NOT NULL,
  "membershipId" UUID NOT NULL,
  "memberId" UUID NOT NULL,
  "fromPriceCents" BIGINT NOT NULL,
  "toPriceCents" BIGINT NOT NULL,
  "wasProtected" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "membership_price_changes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "membership_price_changes_precios_chk" CHECK ("fromPriceCents" >= 0 AND "toPriceCents" >= 0)
);
CREATE UNIQUE INDEX "membership_price_changes_acto_membresia_key" ON "membership_price_changes"("planPriceChangeId", "membershipId");
CREATE INDEX "membership_price_changes_org_membership_idx" ON "membership_price_changes"("organizationId", "membershipId", "createdAt");
ALTER TABLE "membership_price_changes" ADD CONSTRAINT "membership_price_changes_acto_fkey" FOREIGN KEY ("planPriceChangeId") REFERENCES "plan_price_changes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "membership_price_changes" ADD CONSTRAINT "membership_price_changes_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "membership_price_changes" ADD CONSTRAINT "membership_price_changes_membership_fkey" FOREIGN KEY ("membershipId") REFERENCES "memberships"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- La aplicación los escribe y los lee; nunca los corrige ni los borra.
GRANT SELECT, INSERT ON "plan_price_changes" TO gymflow_app;
GRANT SELECT, INSERT ON "membership_price_changes" TO gymflow_app;
REVOKE UPDATE, DELETE ON "plan_price_changes" FROM gymflow_app;
REVOKE UPDATE, DELETE ON "membership_price_changes" FROM gymflow_app;

-- El aviso al teléfono: un motivo más en la bandeja de salida, con el cambio del que avisa.
ALTER TABLE "outbound_messages" ADD COLUMN "priceChangeId" UUID;
ALTER TABLE "outbound_messages" DROP CONSTRAINT "outbound_messages_kind_chk";
ALTER TABLE "outbound_messages" ADD CONSTRAINT "outbound_messages_kind_chk"
  CHECK ("kind" IN ('MEMBERSHIP_SUSPENDED', 'PAYMENT_OVERDUE', 'PAYMENT_DUE_SOON', 'MEMBERSHIP_ENDING', 'WE_MISS_YOU', 'PRICE_CHANGE'));

-- ── D-21 · Costo por producto y precio de socio / de público ────────────────
-- Los dos son opcionales: sin costo, el Tablero sigue contando la venta
-- completa; sin precio de socio, todos pagan el de público (`priceCents`).
ALTER TABLE "products" ADD COLUMN "costCents" BIGINT;
ALTER TABLE "products" ADD COLUMN "memberPriceCents" BIGINT;
ALTER TABLE "products" ADD CONSTRAINT "products_cost_chk" CHECK ("costCents" IS NULL OR "costCents" >= 0);
ALTER TABLE "products" ADD CONSTRAINT "products_member_price_chk" CHECK ("memberPriceCents" IS NULL OR ("memberPriceCents" >= 0 AND "memberPriceCents" <= "priceCents"));

-- La línea guarda lo que costaba el producto ese día (el costo cambia; la
-- venta de hace tres meses resta lo que costó entonces) y a qué precio salió.
-- Las ventas anteriores quedan sin costo: el Tablero no les resta nada.
ALTER TABLE "pos_sale_lines" ADD COLUMN "unitCostCents" BIGINT;
ALTER TABLE "pos_sale_lines" ADD COLUMN "priceKind" TEXT NOT NULL DEFAULT 'PUBLIC';
ALTER TABLE "pos_sale_lines" ADD CONSTRAINT "pos_sale_lines_cost_chk" CHECK ("unitCostCents" IS NULL OR "unitCostCents" >= 0);
ALTER TABLE "pos_sale_lines" ADD CONSTRAINT "pos_sale_lines_price_kind_chk" CHECK ("priceKind" IN ('PUBLIC', 'MEMBER'));
