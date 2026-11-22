-- CreateTable
CREATE TABLE "approval_requests" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "requestedByUserId" UUID NOT NULL,
    "permission" TEXT NOT NULL,
    "branchId" UUID,
    "resourceType" TEXT,
    "resourceId" UUID,
    "amountCents" BIGINT,
    "summary" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "approverUserId" UUID,
    "decidedAt" TIMESTAMPTZ(3),
    "rejectReason" TEXT,
    "deliveryToken" TEXT,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "approval_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "approval_requests_organizationId_status_expiresAt_idx" ON "approval_requests"("organizationId", "status", "expiresAt");

ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_status_chk"
  CHECK ("status" IN ('PENDING','APPROVED','REJECTED','CANCELED','EXPIRED'));
-- Quedan como historia: se cancelan o vencen, no se borran.
REVOKE DELETE ON "approval_requests" FROM gymflow_app;
