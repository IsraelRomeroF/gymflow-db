-- CreateIndex
CREATE INDEX "access_decisions_organizationId_branchId_at_idx" ON "access_decisions"("organizationId", "branchId", "at" DESC);
