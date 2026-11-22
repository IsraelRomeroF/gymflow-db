-- CreateIndex
CREATE INDEX "members_name_trgm_idx" ON "members" USING GIN ("nameKey" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "members_code_trgm_idx" ON "members" USING GIN ("memberCode" gin_trgm_ops);

-- CreateIndex
CREATE INDEX "prospects_name_trgm_idx" ON "prospects" USING GIN ("nameKey" gin_trgm_ops);

