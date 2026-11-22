-- CreateIndex
CREATE INDEX "payments_organizationId_businessDate_idx" ON "payments"("organizationId", "businessDate");
