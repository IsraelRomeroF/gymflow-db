-- Permisos por persona (2026-10-09): encima de su puesto, quien administra al
-- personal enciende o apaga acciones sueltas a recepción y coaches, de una
-- lista cerrada (`ADJUSTABLE_PERMISSIONS` en el núcleo). NULL = como su puesto.
ALTER TABLE "users" ADD COLUMN "permissionOverrides" JSONB;

-- Coach asignado al socio (2026-10-09): el coach ve solo a sus socios. Si el
-- socio no tiene coach asignado, cuenta quien le asignó su rutina vigente.
ALTER TABLE "members" ADD COLUMN "coachUserId" UUID;
ALTER TABLE "members" ADD CONSTRAINT "members_coach_same_org_fk"
  FOREIGN KEY ("coachUserId", "organizationId") REFERENCES "users"("id", "organizationId")
  ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX "members_org_coach_idx" ON "members"("organizationId", "coachUserId") WHERE "coachUserId" IS NOT NULL;
