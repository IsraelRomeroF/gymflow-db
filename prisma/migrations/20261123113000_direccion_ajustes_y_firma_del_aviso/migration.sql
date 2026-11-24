-- DIRECCIÓN (auditoría 8, fase 3, bloque 3.7; decisiones D-22, D-23 y D-25).
-- Aditiva.
--
-- 1. D-22 · Las cifras de un mes cerrado quedan fijas. Lo que llega tarde se
--    anota en el mes en curso como «ajuste de ‹mes›»: `adjustsMonth` dice de
--    qué mes cerrado es. Si el ajuste corrige un gasto de ese mes (lo que
--    antes era anularlo), va en NEGATIVO y apunta a él con `adjustsExpenseId`;
--    el gasto original no se toca.
ALTER TABLE "operating_expenses"
  ADD COLUMN "adjustsMonth" DATE,
  ADD COLUMN "adjustsExpenseId" UUID;

ALTER TABLE "operating_expenses" DROP CONSTRAINT "operating_expenses_amount_chk";
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_amount_chk"
  CHECK ("amountCents" > 0 OR ("amountCents" < 0 AND "adjustsExpenseId" IS NOT NULL));
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_adjusts_month_chk"
  CHECK ("adjustsMonth" IS NULL OR (EXTRACT(DAY FROM "adjustsMonth") = 1 AND "adjustsMonth" < "periodMonth"));
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_adjusts_expense_chk"
  CHECK ("adjustsExpenseId" IS NULL OR "adjustsMonth" IS NOT NULL);
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_adjustsExpenseId_fkey"
  FOREIGN KEY ("adjustsExpenseId") REFERENCES "operating_expenses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- Un gasto de un mes cerrado se corrige una sola vez (mientras el ajuste siga vigente).
CREATE UNIQUE INDEX "operating_expenses_adjusts_expense_key" ON "operating_expenses"("adjustsExpenseId")
  WHERE "adjustsExpenseId" IS NOT NULL AND "voidedAt" IS NULL;

-- 2. D-25 · El aviso de privacidad no se publica sin la firma de la dueña. La
--    gerencia pide publicarlo y queda aquí la solicitud, con el motivo, los
--    puntos que revisó y la huella del texto que revisó: si el borrador cambia
--    después, la firma ya no vale para ese texto.
CREATE TABLE "consent_signature_requests" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "documentId" UUID NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "reason" TEXT NOT NULL,
  "checklist" JSONB NOT NULL DEFAULT '[]',
  "bodyHash" TEXT NOT NULL,
  "requestedByUserId" UUID NOT NULL,
  "requestedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resolvedByUserId" UUID,
  "resolvedAt" TIMESTAMPTZ(3),
  "note" TEXT,
  CONSTRAINT "consent_signature_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "consent_signature_requests_status_chk" CHECK ("status" IN ('PENDING', 'SIGNED', 'REJECTED', 'WITHDRAWN')),
  CONSTRAINT "consent_signature_requests_resuelta_chk" CHECK (("status" = 'PENDING') = ("resolvedAt" IS NULL))
);
-- Una sola solicitud viva por texto.
CREATE UNIQUE INDEX "consent_signature_requests_pending_key" ON "consent_signature_requests"("documentId") WHERE "status" = 'PENDING';
CREATE INDEX "consent_signature_requests_org_status_idx" ON "consent_signature_requests"("organizationId", "status", "requestedAt");
ALTER TABLE "consent_signature_requests" ADD CONSTRAINT "consent_signature_requests_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- Si el borrador se borra, su solicitud se va con él.
ALTER TABLE "consent_signature_requests" ADD CONSTRAINT "consent_signature_requests_documentId_fkey"
  FOREIGN KEY ("documentId") REFERENCES "consent_documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE, DELETE ON "consent_signature_requests" TO gymflow_app;
