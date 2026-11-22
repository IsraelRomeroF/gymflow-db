-- DM-05: precio pactado al vender. Las cuotas se cobran a este precio, no al de lista de hoy.
ALTER TABLE "memberships" ADD COLUMN "agreedPriceCents" BIGINT;
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_agreed_price_nonneg_chk" CHECK ("agreedPriceCents" IS NULL OR "agreedPriceCents" >= 0);
