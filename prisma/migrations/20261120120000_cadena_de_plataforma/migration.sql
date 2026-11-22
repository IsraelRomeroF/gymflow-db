-- Auditoría 8, fase 1, bloque 1.11 (bitácora): CADENA DE PLATAFORMA (24-19,
-- 23-09). Todo es aditivo.
--
-- Hasta hoy lo que GymFlow hacía desde su consola quedaba repartido en la
-- cadena de cada marca (como acto del sistema) y lo que no tocaba a ninguna
-- marca (entrar, reconfirmar, cambiar un plan o un precio) solo en el log.
-- `platform_audit_logs` es UNA cadena de hashes para toda la plataforma:
--   · cada asiento `platform.*` que se escribe en la cadena de una marca deja
--     aquí su espejo, ENLAZADO con el id y el hash del asiento de la marca
--     (`organizationAuditId`, `organizationAuditHash`), en la misma transacción;
--   · lo que solo pasa en la consola se asienta aquí directamente
--     (`organizationId` NULL).
-- `occurredAt` es cuándo pasó; `at`, cuándo se encadenó (son iguales salvo en
-- los asientos anteriores a esta migración, que se importan con el script
-- `scripts/plataforma-cadena-importar.ts` del backend).
CREATE TABLE "platform_audit_logs" (
  "id" UUID NOT NULL,
  "actorUserId" UUID,
  "action" TEXT NOT NULL,
  "organizationId" UUID,
  "resourceType" TEXT NOT NULL,
  "resourceId" TEXT,
  "beforeState" JSONB,
  "afterState" JSONB,
  "reason" TEXT,
  "organizationAuditId" UUID,
  "organizationAuditHash" TEXT,
  "ip" TEXT,
  "userAgent" TEXT,
  "sessionId" UUID,
  "requestId" TEXT,
  "prevHash" TEXT,
  "hash" TEXT NOT NULL,
  "occurredAt" TIMESTAMPTZ(3) NOT NULL,
  "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "platform_audit_logs_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "platform_audit_logs_chain_tip_idx" ON "platform_audit_logs"("at" DESC, "id" DESC);
CREATE INDEX "platform_audit_logs_organizationId_at_idx" ON "platform_audit_logs"("organizationId", "at" DESC);
-- Un asiento de marca tiene a lo más un espejo: importar dos veces no duplica.
CREATE UNIQUE INDEX "platform_audit_logs_organizationAuditId_key" ON "platform_audit_logs"("organizationAuditId");

-- Append-only, igual que `audit_logs`: el hash detecta la manipulación, el
-- trigger la impide y al rol de la aplicación se le revoca editar y borrar.
CREATE TRIGGER "platform_audit_logs_no_update"
  BEFORE UPDATE ON "platform_audit_logs"
  FOR EACH ROW EXECUTE FUNCTION gymflow_audit_is_append_only();

CREATE TRIGGER "platform_audit_logs_no_delete"
  BEFORE DELETE ON "platform_audit_logs"
  FOR EACH ROW EXECUTE FUNCTION gymflow_audit_is_append_only();

REVOKE UPDATE, DELETE ON "platform_audit_logs" FROM gymflow_app;
