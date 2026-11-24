-- DATOS Y MARCA DEL GIMNASIO (auditoría 8, fase 4, bloque 4.6; decisión D-27).
-- Nada de esto se cambia desde el panel del gimnasio: lo administra la
-- plataforma, con motivo y bitácora. Aditiva: agrega columnas vacías y una
-- tabla nueva; no escribe en ninguna fila que ya exista.

-- ── Lo que la plataforma lleva de cada marca ────────────────────────────────
ALTER TABLE "organizations" ADD COLUMN "rfc" TEXT;
-- Teléfono y WhatsApp del gimnasio, en E.164.
ALTER TABLE "organizations" ADD COLUMN "phone" TEXT;
ALTER TABLE "organizations" ADD COLUMN "whatsapp" TEXT;
-- Lo que se imprime al pie del recibo.
ALTER TABLE "organizations" ADD COLUMN "receiptLegend" TEXT;
-- El logo: una imagen pequeña (PNG, JPEG o WebP) guardada como `data:` URL.
ALTER TABLE "organizations" ADD COLUMN "logo" TEXT;
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_logo_chk" CHECK ("logo" IS NULL OR ("logo" LIKE 'data:image/%' AND length("logo") <= 300000));
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_leyenda_chk" CHECK ("receiptLegend" IS NULL OR length("receiptLegend") <= 300);

-- Teléfono y horario de cada sucursal (el horario, en texto: «Lunes a viernes de 6:00 a 22:00»).
ALTER TABLE "branches" ADD COLUMN "phone" TEXT;
ALTER TABLE "branches" ADD COLUMN "openingHours" TEXT;
ALTER TABLE "branches" ADD CONSTRAINT "branches_horario_chk" CHECK ("openingHours" IS NULL OR length("openingHours") <= 300);

-- ── «Pedir un cambio a GymFlow» ─────────────────────────────────────────────
-- La solicitud que la dueña o la gerencia mandan desde «Mi gimnasio»: qué dato,
-- el valor nuevo y por qué. La plataforma la aplica o la rechaza con respuesta;
-- `seenAt` es cuando quien la pidió vio el resultado en su panel.
CREATE TABLE "gym_change_requests" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "branchId" UUID,
  "field" TEXT NOT NULL,
  "proposedValue" TEXT,
  "proposedLogo" TEXT,
  "reason" TEXT NOT NULL,
  "requestedByUserId" UUID NOT NULL,
  "requestedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "response" TEXT,
  "appliedValue" TEXT,
  "resolvedByUserId" UUID,
  "resolvedAt" TIMESTAMPTZ(3),
  "seenAt" TIMESTAMPTZ(3),
  CONSTRAINT "gym_change_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "gym_change_requests_field_chk" CHECK ("field" IN ('LEGAL_NAME', 'RFC', 'TRADE_NAME', 'LOGO', 'PHONE', 'WHATSAPP', 'RECEIPT_LEGEND', 'BRANCH_PHONE', 'BRANCH_HOURS', 'OTHER')),
  CONSTRAINT "gym_change_requests_status_chk" CHECK ("status" IN ('PENDING', 'APPLIED', 'REJECTED')),
  -- Resuelta = tiene fecha; pendiente = no la tiene.
  CONSTRAINT "gym_change_requests_resuelta_chk" CHECK (("status" = 'PENDING') = ("resolvedAt" IS NULL)),
  -- Un rechazo siempre dice por qué.
  CONSTRAINT "gym_change_requests_rechazo_chk" CHECK ("status" <> 'REJECTED' OR "response" IS NOT NULL),
  -- Los datos de sucursal dicen de cuál; los del gimnasio, de ninguna.
  CONSTRAINT "gym_change_requests_sede_chk" CHECK (("field" IN ('BRANCH_PHONE', 'BRANCH_HOURS')) = ("branchId" IS NOT NULL)),
  -- El logo viaja como imagen; lo demás, como texto.
  CONSTRAINT "gym_change_requests_logo_chk" CHECK ("proposedLogo" IS NULL OR ("field" = 'LOGO' AND "proposedLogo" LIKE 'data:image/%' AND length("proposedLogo") <= 300000)),
  -- Nadie ve el resultado de algo que no se ha resuelto.
  CONSTRAINT "gym_change_requests_visto_chk" CHECK ("seenAt" IS NULL OR "resolvedAt" IS NOT NULL)
);
CREATE INDEX "gym_change_requests_org_idx" ON "gym_change_requests"("organizationId", "requestedAt");
CREATE INDEX "gym_change_requests_status_idx" ON "gym_change_requests"("status", "requestedAt");
ALTER TABLE "gym_change_requests" ADD CONSTRAINT "gym_change_requests_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "gym_change_requests" ADD CONSTRAINT "gym_change_requests_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "gym_change_requests" ADD CONSTRAINT "gym_change_requests_requestedByUserId_fkey" FOREIGN KEY ("requestedByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, UPDATE ON "gym_change_requests" TO gymflow_app;
-- La solicitud y su respuesta son la constancia de quién pidió qué: no se borran.
REVOKE DELETE ON "gym_change_requests" FROM gymflow_app;
