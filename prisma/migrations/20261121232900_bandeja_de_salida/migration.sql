-- BANDEJA DE SALIDA (auditoría 8, fase 2, bloque 2.9; hallazgos 25-10, 15-08, 28-14).
-- Aditiva. Un mensaje que el gimnasio le debe a un socio (pago por vencer,
-- pago vencido, suspensión, plan por terminar, «te extrañamos»). Los genera el
-- job `outbound.generate`; recepción los manda con un toque desde una lista
-- (enlace wa.me). Nada sale solo (D-34): `channel` existe para que un
-- proveedor sea después otro enviador de la misma tabla.
CREATE TABLE "outbound_messages" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "branchId" UUID,
  "memberId" UUID NOT NULL,
  "kind" TEXT NOT NULL,
  "channel" TEXT NOT NULL DEFAULT 'WHATSAPP_LINK',
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "dedupeKey" TEXT NOT NULL,
  "chargeId" UUID,
  "membershipId" UUID,
  "engagementState" TEXT,
  "body" TEXT,
  "closeReason" TEXT,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resolvedAt" TIMESTAMPTZ(3),
  "resolvedByUserId" UUID,
  CONSTRAINT "outbound_messages_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "outbound_messages_kind_chk" CHECK ("kind" IN ('MEMBERSHIP_SUSPENDED', 'PAYMENT_OVERDUE', 'PAYMENT_DUE_SOON', 'MEMBERSHIP_ENDING', 'WE_MISS_YOU')),
  CONSTRAINT "outbound_messages_channel_chk" CHECK ("channel" IN ('WHATSAPP_LINK')),
  CONSTRAINT "outbound_messages_status_chk" CHECK ("status" IN ('PENDING', 'SENT', 'DISMISSED', 'EXPIRED')),
  -- Pendiente = sin resolver; lo resuelto dice cuándo.
  CONSTRAINT "outbound_messages_resuelto_chk" CHECK (("status" = 'PENDING') = ("resolvedAt" IS NULL)),
  -- Lo mandado guarda lo que se mandó.
  CONSTRAINT "outbound_messages_mandado_chk" CHECK ("status" <> 'SENT' OR "body" IS NOT NULL)
);
CREATE UNIQUE INDEX "outbound_messages_org_dedupe_key" ON "outbound_messages"("organizationId", "dedupeKey");
CREATE INDEX "outbound_messages_org_status_idx" ON "outbound_messages"("organizationId", "status", "kind");
CREATE INDEX "outbound_messages_org_member_idx" ON "outbound_messages"("organizationId", "memberId", "createdAt");
ALTER TABLE "outbound_messages" ADD CONSTRAINT "outbound_messages_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "outbound_messages" ADD CONSTRAINT "outbound_messages_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE CASCADE ON UPDATE CASCADE;
-- La aplicación lee, crea y resuelve; los privilegios por omisión ya se los dan.
GRANT SELECT, INSERT, UPDATE, DELETE ON "outbound_messages" TO gymflow_app;

-- 15-08: mandar un «te extrañamos» desde la lista anota el contacto de
-- Retención en el mismo toque, con un resultado propio («Se le mandó mensaje»).
-- La columna es texto con CHECK: se sustituye la lista. Lo guardado sigue valiendo.
ALTER TABLE "follow_ups" DROP CONSTRAINT "follow_ups_outcome_check";
ALTER TABLE "follow_ups" ADD CONSTRAINT "follow_ups_outcome_check"
  CHECK ("outcome" IN ('ANSWERED', 'NO_ANSWER', 'INTERESTED', 'NOT_INTERESTED', 'COMING_BACK', 'TRIAL_VISIT', 'INTAKE_SENT', 'MESSAGE_SENT'));
