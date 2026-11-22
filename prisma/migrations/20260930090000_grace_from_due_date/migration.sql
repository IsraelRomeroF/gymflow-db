-- La cuota se cobra al INICIO del periodo (prepago): su vencimiento es
-- `currentPeriodStart`, y la gracia se cuenta desde ahí. La regla anterior
-- exigía que la gracia terminara después del FIN del periodo, lo que suponía
-- cobrar vencido y hacía imposible registrar la mora de un periodo recién
-- renovado sin pagar.
ALTER TABLE "memberships" DROP CONSTRAINT "memberships_grace_order_chk";
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_grace_order_chk"
  CHECK ("graceUntil" IS NULL OR "graceUntil" >= "currentPeriodStart");
