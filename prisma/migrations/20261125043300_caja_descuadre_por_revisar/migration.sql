-- CAJA · D-17 (auditoría 8, fase 4, bloque 4.3).
-- ADITIVA: solo agrega columnas (nulas), restricciones que las filas actuales ya
-- cumplen (todas llegan con las columnas nuevas en NULL) y un índice. No escribe
-- en ninguna fila que ya exista y no depende del día en que se aplique.
--
-- Los cortes que ya existen se quedan con "varianceStatus" en NULL: no entran a
-- «por revisar» aunque su diferencia pase de $20 (la regla vale desde que se
-- aplica). Para contarlos antes, en solo lectura:
--   SELECT count(*) FROM "cash_sessions"
--    WHERE "status" <> 'OPEN' AND abs(coalesce("varianceCents", 0)) > 2000;

-- ── El descuadre «por revisar» ──────────────────────────────────────────────
-- El faltante es de quien ABRIÓ el turno ("openedByUserId": no hace falta otra
-- columna). Un corte que cierra con más de $20 de diferencia nace 'PENDING'; la
-- gerencia lo revisa y lo cierra con su nota ('REVIEWED').
ALTER TABLE "cash_sessions"
  ADD COLUMN "varianceStatus" TEXT,
  ADD COLUMN "varianceReviewedByUserId" UUID,
  ADD COLUMN "varianceReviewedAt" TIMESTAMPTZ(3),
  ADD COLUMN "varianceReviewNote" TEXT;

ALTER TABLE "cash_sessions"
  ADD CONSTRAINT "cash_sessions_variance_status_chk"
    CHECK ("varianceStatus" IS NULL OR "varianceStatus" IN ('PENDING', 'REVIEWED')),
  -- Solo un turno ya cortado y con diferencia tiene algo que revisar.
  ADD CONSTRAINT "cash_sessions_variance_status_cerrado_chk"
    CHECK ("varianceStatus" IS NULL OR ("status" <> 'OPEN' AND "varianceCents" IS NOT NULL AND "varianceCents" <> 0)),
  -- Revisado = con quién, cuándo y su nota; por revisar = sin nada de eso.
  ADD CONSTRAINT "cash_sessions_variance_revisado_chk"
    CHECK (
      ("varianceStatus" = 'REVIEWED' AND "varianceReviewedByUserId" IS NOT NULL AND "varianceReviewedAt" IS NOT NULL
        AND "varianceReviewNote" IS NOT NULL AND length(btrim("varianceReviewNote")) >= 3)
      OR ("varianceStatus" IS DISTINCT FROM 'REVIEWED' AND "varianceReviewedByUserId" IS NULL AND "varianceReviewedAt" IS NULL
        AND "varianceReviewNote" IS NULL)
    );

CREATE INDEX "cash_sessions_org_variance_status_idx" ON "cash_sessions"("organizationId", "varianceStatus");

-- ── «Retiro del dueño» que sale del cajón ───────────────────────────────────
-- El retiro del cajón apunta a su anotación en Movimientos ("operating_expenses",
-- categoría OWNER_DRAW): las dos filas nacen en la misma transacción. La columna
-- se escribe solo al insertar ("cash_movements" es de solo agregar).
ALTER TABLE "cash_movements" ADD COLUMN "expenseId" UUID;
ALTER TABLE "cash_movements" ADD CONSTRAINT "cash_movements_expense_fk"
  FOREIGN KEY ("expenseId") REFERENCES "operating_expenses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- Un gasto no respalda dos retiros.
CREATE UNIQUE INDEX "cash_movements_expense_key" ON "cash_movements"("expenseId");
