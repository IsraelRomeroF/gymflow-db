-- NÓMINA POR PAGO Y GASTOS QUE SE REPITEN (auditoría 8, fase 4, bloque 4.5; decisión D-26).
-- Aditiva: columnas que nacen vacías y dos tablas nuevas. No escribe en ninguna
-- fila que ya exista; las restricciones nuevas las cumple todo gasto anterior
-- (sus columnas nuevas quedan en NULL).
--
-- 1. La nómina se anota POR PAGO: fecha (`paidOn`), a quién (`payeeUserId` si
--    es del personal y `payeeName`, su nombre al anotarlo o el escrito a mano)
--    y cuánto. El pago cuenta en el mes de su fecha, como cualquier gasto del
--    mes. La nómina anotada antes como un total del mes se queda como está:
--    sin fecha ni persona.
ALTER TABLE "operating_expenses"
  ADD COLUMN "paidOn" DATE,
  ADD COLUMN "payeeUserId" UUID,
  ADD COLUMN "payeeName" TEXT,
  ADD COLUMN "recurringId" UUID,
  ADD COLUMN "recurringDue" DATE;

-- Fecha y persona van juntas, y solo en la nómina.
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_payee_chk"
  CHECK (("paidOn" IS NULL) = ("payeeName" IS NULL)
     AND ("payeeUserId" IS NULL OR "payeeName" IS NOT NULL)
     AND ("payeeName" IS NULL OR ("category" = 'PAYROLL' AND length(btrim("payeeName")) >= 2)));
-- El pago cuenta en el mes de su fecha; si ese mes ya estaba cerrado, es un
-- «ajuste de ‹mes›» de ese mes (D-22). El ajuste en negativo que corrige un
-- pago copia su fecha tal cual.
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_paid_on_month_chk"
  CHECK ("paidOn" IS NULL OR "adjustsExpenseId" IS NOT NULL
      OR date_trunc('month', "paidOn")::date = COALESCE("adjustsMonth", "periodMonth"));

-- 2. Gastos que se repiten (renta, luz, la nómina fija…). La fila es la
--    plantilla: NO es un gasto y no cuenta en ninguna cifra. Cada periodo
--    propone un gasto «por confirmar»; alguien lo confirma (nace el gasto,
--    enlazado con `recurringId` y `recurringDue`), corrige el importe o lo
--    descarta. Nada se anota solo.
CREATE TABLE "recurring_expenses" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "branchId" UUID,
  "category" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "amountCents" BIGINT NOT NULL,
  "frequency" TEXT NOT NULL,
  "startsOn" DATE NOT NULL,
  "payeeUserId" UUID,
  "payeeName" TEXT,
  "createdByUserId" UUID NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "endedAt" TIMESTAMPTZ(3),
  "endedByUserId" UUID,
  "endReason" TEXT,
  CONSTRAINT "recurring_expenses_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "recurring_expenses_amount_chk" CHECK ("amountCents" > 0),
  CONSTRAINT "recurring_expenses_frequency_chk" CHECK ("frequency" IN ('MONTHLY', 'BIWEEKLY', 'WEEKLY')),
  -- El «Retiro del dueño» no es un gasto y no se propone solo.
  CONSTRAINT "recurring_expenses_category_chk"
    CHECK ("category" IN ('RENT','PAYROLL','UTILITIES','SERVICES','MAINTENANCE','MARKETING','TAXES','OTHER')),
  CONSTRAINT "recurring_expenses_payee_chk"
    CHECK ((("category" = 'PAYROLL') = ("payeeName" IS NOT NULL))
       AND ("payeeUserId" IS NULL OR "payeeName" IS NOT NULL)
       AND ("payeeName" IS NULL OR length(btrim("payeeName")) >= 2)),
  CONSTRAINT "recurring_expenses_ended_chk" CHECK (("endedAt" IS NULL) = ("endedByUserId" IS NULL))
);
CREATE INDEX "recurring_expenses_organizationId_endedAt_idx" ON "recurring_expenses"("organizationId", "endedAt");
-- Se deja de repetir con motivo; no se borra (queda de qué salieron los gastos ya confirmados).
GRANT SELECT, INSERT, UPDATE ON "recurring_expenses" TO gymflow_app;
REVOKE DELETE ON "recurring_expenses" FROM gymflow_app;

ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_recurring_chk"
  CHECK (("recurringId" IS NULL) = ("recurringDue" IS NULL));
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_recurringId_fkey"
  FOREIGN KEY ("recurringId") REFERENCES "recurring_expenses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- Una propuesta se confirma una sola vez (mientras el gasto siga vigente: si
-- se anula, vuelve a quedar por confirmar).
CREATE UNIQUE INDEX "operating_expenses_recurring_due_key" ON "operating_expenses"("recurringId", "recurringDue")
  WHERE "recurringId" IS NOT NULL AND "voidedAt" IS NULL;

-- 3. La propuesta que alguien descartó: queda quién y cuándo, y no se vuelve a proponer.
CREATE TABLE "recurring_expense_skips" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "recurringId" UUID NOT NULL,
  "dueOn" DATE NOT NULL,
  "reason" TEXT,
  "skippedByUserId" UUID NOT NULL,
  "skippedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "recurring_expense_skips_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "recurring_expense_skips_recurringId_dueOn_key" ON "recurring_expense_skips"("recurringId", "dueOn");
CREATE INDEX "recurring_expense_skips_organizationId_dueOn_idx" ON "recurring_expense_skips"("organizationId", "dueOn");
ALTER TABLE "recurring_expense_skips" ADD CONSTRAINT "recurring_expense_skips_recurringId_fkey"
  FOREIGN KEY ("recurringId") REFERENCES "recurring_expenses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- Solo agregar: un descarte no se corrige ni se borra.
GRANT SELECT, INSERT ON "recurring_expense_skips" TO gymflow_app;
REVOKE UPDATE, DELETE ON "recurring_expense_skips" FROM gymflow_app;
