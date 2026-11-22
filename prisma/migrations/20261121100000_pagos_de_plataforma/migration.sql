-- COBRO DE PLATAFORMA (auditoría 8, bloque 1.13; hallazgos 23-07 y 23-08).
-- Un pago es una fila propia: la factura se paga en uno o en varios abonos y
-- un pago registrado por error se DESHACE (con motivo), no se borra.
-- Aditiva: lo ya pagado se conserva como un pago por el total.

-- CreateTable
CREATE TABLE "platform_payments" (
    "id" UUID NOT NULL,
    "invoiceId" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "amountCents" BIGINT NOT NULL,
    "paymentMethod" TEXT NOT NULL,
    "paymentRef" TEXT,
    "paidOn" DATE NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdByUserId" UUID,
    "undoneAt" TIMESTAMPTZ(3),
    "undoneByUserId" UUID,
    "undoReason" TEXT,

    CONSTRAINT "platform_payments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "platform_payments_invoiceId_createdAt_idx" ON "platform_payments"("invoiceId", "createdAt");

-- AddForeignKey
ALTER TABLE "platform_payments" ADD CONSTRAINT "platform_payments_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "platform_invoices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AlterTable
ALTER TABLE "platform_invoices" ADD COLUMN "paidCents" BIGINT NOT NULL DEFAULT 0;

ALTER TABLE "platform_payments" ADD CONSTRAINT "platform_payments_amount_chk" CHECK ("amountCents" > 0);
ALTER TABLE "platform_payments" ADD CONSTRAINT "platform_payments_method_chk"
  CHECK ("paymentMethod" IN ('SPEI_TRANSFER','CARD','CASH','OTHER'));
-- Deshecho con su motivo, o vivo: nunca a medias.
ALTER TABLE "platform_payments" ADD CONSTRAINT "platform_payments_undo_chk"
  CHECK (("undoneAt" IS NULL AND "undoReason" IS NULL) OR ("undoneAt" IS NOT NULL AND "undoReason" IS NOT NULL));

-- Lo que ya estaba pagado: un pago por el total, con la forma, la referencia
-- y el día (de la Ciudad de México) que se registraron.
INSERT INTO "platform_payments" ("id", "invoiceId", "organizationId", "amountCents", "paymentMethod", "paymentRef", "paidOn", "createdAt")
SELECT gen_random_uuid(), f."id", f."organizationId", f."totalCents",
       CASE WHEN f."paymentMethod" IN ('SPEI_TRANSFER','CARD','CASH','OTHER') THEN f."paymentMethod" ELSE 'OTHER' END,
       f."paymentRef",
       (COALESCE(f."paidAt", f."issuedAt") AT TIME ZONE 'America/Mexico_City')::date,
       COALESCE(f."paidAt", f."issuedAt")
  FROM "platform_invoices" f
 WHERE f."status" = 'PAID' AND f."totalCents" > 0;

UPDATE "platform_invoices" SET "paidCents" = "totalCents" WHERE "status" = 'PAID';

-- Lo pagado nunca pasa del total ni baja de cero; pagada = pagado completo.
ALTER TABLE "platform_invoices" ADD CONSTRAINT "platform_invoices_paid_chk"
  CHECK ("paidCents" >= 0 AND "paidCents" <= "totalCents");
ALTER TABLE "platform_invoices" ADD CONSTRAINT "platform_invoices_paid_status_chk"
  CHECK ("status" <> 'PAID' OR "paidCents" = "totalCents");

-- Un pago no se borra: se deshace.
REVOKE DELETE ON "platform_payments" FROM gymflow_app;
