-- UX7 · Seguimiento real en Prospectos y Retención: cada contacto ("le llamé",
-- "le escribí") con su resultado, su nota y el próximo paso. Es bitácora de
-- trabajo: la API solo agrega; corregir es otro contacto, no reescribir.
CREATE TABLE "follow_ups" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "branchId" UUID,
  "prospectId" UUID,
  "memberId" UUID,
  "channel" TEXT NOT NULL,
  "outcome" TEXT NOT NULL,
  "note" TEXT,
  "nextStepOn" DATE,
  "createdByUserId" UUID NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "follow_ups_pkey" PRIMARY KEY ("id"),
  -- De un prospecto O de un socio, nunca de los dos ni de nadie.
  CONSTRAINT "follow_ups_un_sujeto" CHECK (("prospectId" IS NULL) <> ("memberId" IS NULL)),
  CONSTRAINT "follow_ups_channel_check" CHECK ("channel" IN ('CALL', 'WHATSAPP', 'VISIT', 'OTHER')),
  CONSTRAINT "follow_ups_outcome_check" CHECK ("outcome" IN ('ANSWERED', 'NO_ANSWER', 'INTERESTED', 'NOT_INTERESTED', 'COMING_BACK'))
);
CREATE INDEX "follow_ups_org_prospect_idx" ON "follow_ups"("organizationId", "prospectId", "createdAt");
CREATE INDEX "follow_ups_org_member_idx" ON "follow_ups"("organizationId", "memberId", "createdAt");
ALTER TABLE "follow_ups" ADD CONSTRAINT "follow_ups_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "follow_ups" ADD CONSTRAINT "follow_ups_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "follow_ups" ADD CONSTRAINT "follow_ups_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE CASCADE ON UPDATE CASCADE;
GRANT SELECT, INSERT ON "follow_ups" TO gymflow_app;
