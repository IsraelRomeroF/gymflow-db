-- Fase 4: cierre de mes firmado por el dueño. Append-only para la API: un mes cerrado no se reescribe.
CREATE TABLE "monthly_closes" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "month" DATE NOT NULL,
  "totals" JSONB NOT NULL,
  "byBranch" JSONB NOT NULL,
  "closedByUserId" UUID NOT NULL,
  "closedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "note" TEXT,
  CONSTRAINT "monthly_closes_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "monthly_closes_org_month_key" ON "monthly_closes"("organizationId", "month");
ALTER TABLE "monthly_closes" ADD CONSTRAINT "monthly_closes_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT ON "monthly_closes" TO gymflow_app;
