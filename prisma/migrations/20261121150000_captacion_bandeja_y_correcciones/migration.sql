-- CAPTACIÓN (auditoría 8, fase 2, bloque 2.4; hallazgos 10-05, 10-09, 10-16, 10-17 y 9-21).
-- Aditiva y segura con datos reales: solo agrega columnas, una tabla y dos índices.
--
--  · La bandeja de interesados se ordena y se pagina en SQL: cada interesado
--    guarda cuándo fue su último contacto, su próximo paso y desde qué día toca.
--  · Cerrar a un interesado guarda por qué, cuándo y quién.
--  · «¿Cómo se enteró?» pasa a ser una lista de la gerencia, con quién lo recomendó.
--  · Un alta digital guarda lo que recepción corrigió sin aprobarla todavía.

ALTER TABLE "prospects"
  ADD COLUMN "lastContactAt" TIMESTAMPTZ(3),
  ADD COLUMN "nextStepOn" DATE,
  ADD COLUMN "dueOn" DATE,
  ADD COLUMN "referredByMemberId" UUID,
  ADD COLUMN "referredByName" TEXT,
  ADD COLUMN "lostReasonCode" TEXT,
  ADD COLUMN "lostReason" TEXT,
  ADD COLUMN "closedAt" TIMESTAMPTZ(3),
  ADD COLUMN "closedByUserId" UUID;

-- Lo que ya existía: el último contacto de cada interesado y su próximo paso
-- (el del contacto más reciente). Quien fue contactado y no tiene próximo
-- paso «toca» desde el día de ese contacto, en la zona del gimnasio.
WITH ultimo AS (
  SELECT DISTINCT ON (f."prospectId") f."prospectId", f."createdAt", f."nextStepOn"
    FROM "follow_ups" f
   WHERE f."prospectId" IS NOT NULL
   ORDER BY f."prospectId", f."createdAt" DESC
)
UPDATE "prospects" p
   SET "lastContactAt" = u."createdAt",
       "nextStepOn" = u."nextStepOn",
       "dueOn" = COALESCE(u."nextStepOn", (u."createdAt" AT TIME ZONE o."timezone")::date)
  FROM ultimo u, "organizations" o
 WHERE u."prospectId" = p."id" AND o."id" = p."organizationId";

-- Los ya cerrados: se cerraron cuando se tocaron por última vez (o al inscribirse).
UPDATE "prospects"
   SET "closedAt" = COALESCE("convertedAt", "updatedAt")
 WHERE "status" IN ('CONVERTED', 'LOST') AND "closedAt" IS NULL;

CREATE INDEX "prospects_org_status_due_idx" ON "prospects"("organizationId", "status", "dueOn");
CREATE INDEX "prospects_org_phone_idx" ON "prospects"("organizationId", "phoneE164");

-- «¿Cómo se enteró?»: sin filas, el gimnasio usa las de fábrica.
CREATE TABLE "prospect_sources" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "prospect_sources_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "prospect_sources_org_name_key" ON "prospect_sources"("organizationId", "name");
ALTER TABLE "prospect_sources" ADD CONSTRAINT "prospect_sources_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Alta digital: lo corregido por recepción, guardado sin aprobar (9-21).
ALTER TABLE "member_intakes"
  ADD COLUMN "corrections" JSONB,
  ADD COLUMN "correctedAt" TIMESTAMPTZ(3),
  ADD COLUMN "correctedByUserId" UUID;
