-- CreateTable
CREATE TABLE "approval_grants" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "approverUserId" UUID NOT NULL,
    "requestedByUserId" UUID NOT NULL,
    "permission" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "usedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "approval_grants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "approval_grants_tokenHash_key" ON "approval_grants"("tokenHash");

-- CreateIndex
CREATE INDEX "approval_grants_organizationId_approverUserId_createdAt_idx" ON "approval_grants"("organizationId", "approverUserId", "createdAt");

-- La app solo emite y consume aprobaciones: nunca las borra.
REVOKE DELETE ON "approval_grants" FROM gymflow_app;
