-- Fase 3 (auditoría 6): avisos al socio (PS-03), solicitudes ARCO (PS-07) y Web Push del personal (DP-10).

CREATE TABLE "member_notices" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "memberId" UUID NOT NULL,
  "kind" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "dedupeKey" TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "readAt" TIMESTAMPTZ(3),
  CONSTRAINT "member_notices_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "member_notices_org_dedupe_key" ON "member_notices"("organizationId", "dedupeKey");
CREATE INDEX "member_notices_organizationId_memberId_createdAt_idx" ON "member_notices"("organizationId", "memberId", "createdAt");
ALTER TABLE "member_notices" ADD CONSTRAINT "notices_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "member_notices" ADD CONSTRAINT "member_notices_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "privacy_requests" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "memberId" UUID NOT NULL,
  "kind" TEXT NOT NULL,
  "channel" TEXT NOT NULL,
  "note" TEXT,
  "receivedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "dueAt" TIMESTAMPTZ(3) NOT NULL,
  "resolvedAt" TIMESTAMPTZ(3),
  "resolvedByUserId" UUID,
  "resolution" TEXT,
  "createdByUserId" UUID,
  CONSTRAINT "privacy_requests_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "privacy_requests_organizationId_resolvedAt_dueAt_idx" ON "privacy_requests"("organizationId", "resolvedAt", "dueAt");
CREATE INDEX "privacy_requests_organizationId_memberId_idx" ON "privacy_requests"("organizationId", "memberId");
ALTER TABLE "privacy_requests" ADD CONSTRAINT "privacy_requests_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "privacy_requests" ADD CONSTRAINT "privacy_requests_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "privacy_requests" ADD CONSTRAINT "privacy_requests_kind_chk" CHECK ("kind" IN ('ACCESS','RECTIFICATION','CANCELLATION','OPPOSITION','REVOCATION'));
ALTER TABLE "privacy_requests" ADD CONSTRAINT "privacy_requests_channel_chk" CHECK ("channel" IN ('FRONT_DESK','PORTAL','EMAIL','WRITTEN'));

CREATE TABLE "push_subscriptions" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "endpoint" TEXT NOT NULL,
  "p256dh" TEXT NOT NULL,
  "auth" TEXT NOT NULL,
  "userAgent" TEXT,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastUsedAt" TIMESTAMPTZ(3),
  "failedAt" TIMESTAMPTZ(3),
  CONSTRAINT "push_subscriptions_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "push_subscriptions_endpoint_key" ON "push_subscriptions"("endpoint");
CREATE INDEX "push_subscriptions_organizationId_userId_idx" ON "push_subscriptions"("organizationId", "userId");
ALTER TABLE "push_subscriptions" ADD CONSTRAINT "push_subscriptions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "push_subscriptions" ADD CONSTRAINT "push_subscriptions_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- El rol de la API escribe y lee; las solicitudes ARCO no se borran.
GRANT SELECT, INSERT, UPDATE, DELETE ON "member_notices" TO gymflow_app;
GRANT SELECT, INSERT, UPDATE ON "privacy_requests" TO gymflow_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON "push_subscriptions" TO gymflow_app;
