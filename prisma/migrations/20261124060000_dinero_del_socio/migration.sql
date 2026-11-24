-- DINERO DEL SOCIO (auditoría 8, fase 3, bloque 3.5; decisiones D-13, D-15 y D-16).
-- Aditiva. Lo único que escribe en filas que ya existen es el apartado de las
-- clases sueltas FUTURAS sin pagar (al final, explicado).

-- ── D-13 · Tienda: «por corregir» y devolución de otro día ──────────────────
-- Recepción no anula: avisa. La marca vive en su propia tabla porque
-- `pos_sales` no admite cambios cuando su turno ya se cortó (trigger
-- `pos_sales_cash_session_open`), y una venta se puede marcar al día siguiente.
CREATE TABLE "pos_sale_flags" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "posSaleId" UUID NOT NULL,
  "branchId" UUID NOT NULL,
  "reason" TEXT NOT NULL,
  "flaggedByUserId" UUID NOT NULL,
  "flaggedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- Cómo se resolvió: se anuló (el mismo día), se devolvió (otro día) o no procedía.
  "resolution" TEXT,
  "resolvedByUserId" UUID,
  "resolvedAt" TIMESTAMPTZ(3),
  "resolutionNote" TEXT,
  CONSTRAINT "pos_sale_flags_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "pos_sale_flags_reason_chk" CHECK (length(btrim("reason")) >= 3),
  CONSTRAINT "pos_sale_flags_resolution_chk" CHECK ("resolution" IS NULL OR "resolution" IN ('VOIDED', 'RETURNED', 'DISMISSED')),
  CONSTRAINT "pos_sale_flags_resuelta_chk" CHECK (("resolution" IS NULL) = ("resolvedAt" IS NULL) AND ("resolution" IS NULL) = ("resolvedByUserId" IS NULL))
);
-- Una marca por venta: volver a marcarla reabre la misma fila.
CREATE UNIQUE INDEX "pos_sale_flags_sale_key" ON "pos_sale_flags"("posSaleId");
CREATE INDEX "pos_sale_flags_org_branch_idx" ON "pos_sale_flags"("organizationId", "branchId", "resolvedAt");
ALTER TABLE "pos_sale_flags" ADD CONSTRAINT "pos_sale_flags_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "pos_sale_flags" ADD CONSTRAINT "pos_sale_flags_sale_same_org_fk" FOREIGN KEY ("posSaleId", "organizationId") REFERENCES "pos_sales"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE ON "pos_sale_flags" TO gymflow_app;
REVOKE DELETE ON "pos_sale_flags" FROM gymflow_app;

-- La devolución de una venta de OTRO día (la del mismo día se anula): el
-- dinero sale hoy (del turno abierto, o por transferencia con su referencia),
-- el producto vuelve al inventario y la venta original no se toca: sus cifras
-- del día ya se cortaron y firmaron. Siempre con la firma de la dueña.
CREATE TABLE "pos_sale_returns" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "posSaleId" UUID NOT NULL,
  "branchId" UUID NOT NULL,
  "amountCents" BIGINT NOT NULL,
  -- Por dónde regresa el dinero: el método de la venta.
  "method" "PaymentMethodType" NOT NULL,
  -- El turno abierto del que sale (efectivo o terminal en una sede con Caja).
  "cashSessionId" UUID,
  -- Clave de rastreo de la devolución por transferencia.
  "returnRef" TEXT,
  "reason" TEXT NOT NULL,
  "approvedByUserId" UUID NOT NULL,
  "createdByUserId" UUID NOT NULL,
  -- El día de la sede en que se devolvió: ahí resta en Movimientos.
  "businessDate" DATE NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pos_sale_returns_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "pos_sale_returns_amount_chk" CHECK ("amountCents" > 0),
  CONSTRAINT "pos_sale_returns_reason_chk" CHECK (length(btrim("reason")) >= 3),
  CONSTRAINT "pos_sale_returns_firma_chk" CHECK ("approvedByUserId" <> "createdByUserId")
);
-- Una venta se devuelve una sola vez, entera.
CREATE UNIQUE INDEX "pos_sale_returns_sale_key" ON "pos_sale_returns"("posSaleId");
CREATE INDEX "pos_sale_returns_org_branch_date_idx" ON "pos_sale_returns"("organizationId", "branchId", "businessDate");
CREATE INDEX "pos_sale_returns_session_idx" ON "pos_sale_returns"("cashSessionId");
ALTER TABLE "pos_sale_returns" ADD CONSTRAINT "pos_sale_returns_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "pos_sale_returns" ADD CONSTRAINT "pos_sale_returns_sale_same_org_fk" FOREIGN KEY ("posSaleId", "organizationId") REFERENCES "pos_sales"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "pos_sale_returns" ADD CONSTRAINT "pos_sale_returns_session_same_org_fk" FOREIGN KEY ("cashSessionId", "organizationId") REFERENCES "cash_sessions"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT ON "pos_sale_returns" TO gymflow_app;
REVOKE UPDATE, DELETE ON "pos_sale_returns" FROM gymflow_app;

-- ── D-15 · Los topes del cajón, por gimnasio ────────────────────────────────
-- Sin fila, valen los del núcleo ($500 y $5,000). La dueña los ajusta.
CREATE TABLE "cash_settings" (
  "organizationId" UUID NOT NULL,
  -- Fondo y gastos del cajón que se anotan con motivo y sin firma, por turno y por tipo.
  "pettyLimitCents" BIGINT NOT NULL,
  -- Lo que recepción puede retirar o depositar por turno (siempre con firma).
  "withdrawalShiftLimitCents" BIGINT NOT NULL,
  "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedByUserId" UUID,
  CONSTRAINT "cash_settings_pkey" PRIMARY KEY ("organizationId"),
  CONSTRAINT "cash_settings_rangos_chk" CHECK ("pettyLimitCents" >= 0 AND "pettyLimitCents" <= 1000000 AND "withdrawalShiftLimitCents" >= 0 AND "withdrawalShiftLimitCents" <= 10000000)
);
ALTER TABLE "cash_settings" ADD CONSTRAINT "cash_settings_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE ON "cash_settings" TO gymflow_app;

-- ── D-16 · La clase suelta apartada sin pagar se guarda hasta una hora antes ─
-- `holdUntil`: hasta cuándo se guarda el lugar de una reserva que todavía debe
-- su clase suelta. Pasada esa hora sin pago, el lugar se libera y el cargo se
-- anula (no debe nada). Nulo = no es un apartado (incluida en su plan, ya
-- pagada, o reserva anterior a esta regla).
ALTER TABLE "class_bookings" ADD COLUMN "holdUntil" TIMESTAMPTZ(3);
CREATE INDEX "class_bookings_hold_idx" ON "class_bookings"("organizationId", "holdUntil");

-- Las reservas que YA existen: solo las de clases que empiezan dentro de MÁS
-- de una hora y cuya clase suelta sigue sin ningún pago pasan a la regla
-- nueva (se guardan hasta una hora antes). Las de clases que empiezan en
-- menos de una hora no se tocan: liberarlas al aplicar la migración le
-- quitaría el lugar a alguien que ya va en camino. Las de clases pasadas
-- tampoco: lo que ya se debe no se borra solo (D-12).
UPDATE "class_bookings" b
   SET "holdUntil" = s."startsAt" - INTERVAL '60 minutes'
  FROM "class_schedules" s, "charges" c
 WHERE s."id" = b."classScheduleId"
   AND c."id" = b."chargeId"
   AND b."status" = 'BOOKED'
   AND b."holdUntil" IS NULL
   AND s."startsAt" > now() + INTERVAL '60 minutes'
   AND c."status" IN ('OPEN', 'OVERDUE')
   AND c."allocatedCents" = 0;
