-- BE2-01: un pago admite VARIOS reembolsos parciales. El UNIQUE sobre
-- "reversesPaymentId" venía de cuando solo existía la reversa total, y el
-- segundo reembolso chocaba DESPUÉS de que el procesador ya había devuelto el
-- dinero: salía dinero sin asiento, y cada reintento devolvía otra vez.
ALTER TABLE "payments" ADD COLUMN "isRefund" BOOLEAN NOT NULL DEFAULT false;
UPDATE "payments" SET "isRefund" = true WHERE "reversalReason" LIKE 'Reembolso:%';

DROP INDEX "payments_reversesPaymentId_key";
-- Reversa total: sigue siendo una sola por pago.
CREATE UNIQUE INDEX "payments_single_reversal_key" ON "payments" ("reversesPaymentId")
  WHERE "reversesPaymentId" IS NOT NULL AND NOT "isRefund";
-- Buscar los contra-asientos de un pago.
CREATE INDEX "payments_reversesPaymentId_idx" ON "payments" ("reversesPaymentId");
