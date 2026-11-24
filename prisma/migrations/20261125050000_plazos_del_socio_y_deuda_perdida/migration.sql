-- PLAZOS DEL SOCIO Y DEUDA QUE SE DA POR PERDIDA (auditoría 8, fase 4, bloque 4.4; decisión D-18).
-- Aditiva de verdad: una tabla nueva (vacía) y una columna nueva (nula en todas
-- las filas). No escribe en ninguna fila que ya exista ni depende del día en
-- que se aplique. Lo que cambia para los datos que ya existen lo hacen los
-- jobs del cierre diario la primera noche (ver el informe 4.4, «Qué pasa con
-- los datos que ya existen», y `scripts/plazos-estado.ts`, que lo cuenta antes).

-- ── Los plazos, por gimnasio ────────────────────────────────────────────────
-- Sin fila, o con una columna nula, vale el de fábrica del núcleo
-- (`PLAZOS_DEL_SOCIO`: 21, 30, 60, 6 meses, 7 y 90). Los cuatro primeros los
-- ajusta la gerencia; los dos últimos, solo con la firma de la dueña. Los
-- límites son los de `DEFINICION_DE_PLAZOS`.
CREATE TABLE "member_term_settings" (
  "organizationId" UUID NOT NULL,
  -- Días sin venir para «dejó de venir».
  "dormantDays" INTEGER,
  -- Días de terminada la membresía, sin renovar, para contar como baja.
  "churnDays" INTEGER,
  -- Días sin venir para darlo por perdido.
  "lostDays" INTEGER,
  -- Meses que se le busca en «Recuperar».
  "winbackMonths" INTEGER,
  -- Días para cancelar sola una venta que nadie cobró.
  "unpaidSaleDays" INTEGER,
  -- Días de suspendida para terminar la membresía y dar su deuda por perdida.
  "lostDebtDays" INTEGER,
  "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedByUserId" UUID,
  CONSTRAINT "member_term_settings_pkey" PRIMARY KEY ("organizationId"),
  CONSTRAINT "member_term_settings_rangos_chk" CHECK (
    ("dormantDays" IS NULL OR "dormantDays" BETWEEN 7 AND 60)
    AND ("churnDays" IS NULL OR "churnDays" BETWEEN 1 AND 120)
    AND ("lostDays" IS NULL OR "lostDays" BETWEEN 14 AND 180)
    AND ("winbackMonths" IS NULL OR "winbackMonths" BETWEEN 1 AND 24)
    AND ("unpaidSaleDays" IS NULL OR "unpaidSaleDays" BETWEEN 1 AND 60)
    AND ("lostDebtDays" IS NULL OR "lostDebtDays" BETWEEN 30 AND 365)
  )
);
ALTER TABLE "member_term_settings" ADD CONSTRAINT "member_term_settings_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE ON "member_term_settings" TO gymflow_app;

-- ── La deuda que se da por perdida ──────────────────────────────────────────
-- El día (de la sede) en que un cargo sin pagar salió de «Por cobrar» porque
-- su membresía llevó suspendida el plazo del gimnasio y terminó. NO es una
-- condonación ni una anulación (D-12: nada se borra solo): el cargo conserva
-- su estado y su saldo, sigue en el estado de cuenta y se puede cobrar. Solo
-- deja de sumarse en la cartera. Nulo = deuda normal.
ALTER TABLE "charges" ADD COLUMN "lostOn" DATE;
