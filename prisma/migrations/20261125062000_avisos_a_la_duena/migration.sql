-- AVISOS AL TELÉFONO DE LA DUEÑA Y RESUMEN DEL LUNES (auditoría 8, fase 4,
-- bloque 4.2; decisión D-05, opción c).
-- Aditiva: tres tablas nuevas que nacen vacías. No escribe en ninguna fila que
-- ya exista y no depende del día en que se aplique.
--
--  · `owner_alerts`: cada aviso que el sistema le da a la dueña (una caja que
--    amaneció sin cortar, un corte con diferencia por revisar…) y cada resumen
--    del lunes. Es lo que se ve DENTRO del panel aunque el teléfono no suene.
--    `dedupeKey` es lo que impide mandar dos veces lo mismo: el job puede
--    correr las veces que sea. El texto (`title`, `body`) no lleva nombres de
--    socios; `detail` guarda las cifras y los renglones del detalle.
--  · `owner_alert_starts`: desde qué instante avisa cada gimnasio. Lo escribe
--    la PRIMERA corrida del job `audit.anomaly-scan`: lo anterior a ese
--    instante no se manda (no suena de golpe todo el pasado).
--  · `push_preferences`: qué avisos apagó cada persona en su teléfono. Sin
--    fila, encendido. Apagado, el aviso sigue saliendo dentro del panel.

CREATE TABLE "owner_alerts" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "dedupeKey" TEXT NOT NULL,
    "branchId" UUID,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "detail" JSONB NOT NULL DEFAULT '{}',
    "occurredAt" TIMESTAMPTZ(3) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "silent" BOOLEAN NOT NULL DEFAULT false,
    "pushedAt" TIMESTAMPTZ(3),
    "pushDevices" INTEGER NOT NULL DEFAULT 0,
    "seenAt" TIMESTAMPTZ(3),
    "seenByUserId" UUID,

    CONSTRAINT "owner_alerts_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "owner_alerts_org_dedupe_key" ON "owner_alerts"("organizationId", "dedupeKey");
CREATE INDEX "owner_alerts_org_created_idx" ON "owner_alerts"("organizationId", "createdAt");
CREATE INDEX "owner_alerts_org_kind_idx" ON "owner_alerts"("organizationId", "kind", "createdAt");
ALTER TABLE "owner_alerts" ADD CONSTRAINT "owner_alerts_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "owner_alert_starts" (
    "organizationId" UUID NOT NULL,
    "startedAt" TIMESTAMPTZ(3) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "owner_alert_starts_pkey" PRIMARY KEY ("organizationId")
);
ALTER TABLE "owner_alert_starts" ADD CONSTRAINT "owner_alert_starts_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "push_preferences" (
    "userId" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "organizationId" UUID NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "push_preferences_pkey" PRIMARY KEY ("userId", "kind")
);
CREATE INDEX "push_preferences_org_kind_idx" ON "push_preferences"("organizationId", "kind");
ALTER TABLE "push_preferences" ADD CONSTRAINT "push_preferences_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "push_preferences" ADD CONSTRAINT "push_preferences_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- El rol de la aplicación nace con todos los permisos sobre las tablas nuevas; aquí se le quitan los que no usa.
-- Un aviso no se borra: se crea, se marca como mandado y como visto.
REVOKE DELETE ON "owner_alerts" FROM gymflow_app;
-- El arranque se escribe una vez y se lee: moverlo o borrarlo haría sonar de golpe lo pasado.
REVOKE UPDATE, DELETE ON "owner_alert_starts" FROM gymflow_app;
-- La preferencia se crea y se cambia; no se borra (apagar es `enabled = false`).
REVOKE DELETE ON "push_preferences" FROM gymflow_app;
