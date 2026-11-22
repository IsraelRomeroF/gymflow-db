-- Auditoría 8, bloque 1.10 (21-03, 21-18): el ciclo completo de una solicitud ARCO.
--
--  · identidad: una solicitud por correo o por escrito no corre plazo hasta que
--    alguien acredita que la pide el titular;
--  · resultado: «procede» o «no procede» (antes solo «resuelta»);
--  · segundo plazo: lo que procede se hace efectivo en 15 días hábiles;
--  · permiso: de cuál se opone o cuál revoca, para retirarlo en el mismo acto.
--
-- Aditiva y segura con datos reales. Las solicitudes que ya existían corrían
-- su plazo desde que entraron: se les asienta la identidad en esa fecha. Las
-- ya resueltas quedan sin resultado (cerradas): no se inventa lo que no se registró.

ALTER TABLE "privacy_requests"
  ADD COLUMN "consentType" TEXT,
  ADD COLUMN "identityVerifiedAt" TIMESTAMPTZ(3),
  ADD COLUMN "identityVerifiedByUserId" UUID,
  ADD COLUMN "identityNote" TEXT,
  ADD COLUMN "outcome" TEXT,
  ADD COLUMN "effectiveDueAt" TIMESTAMPTZ(3),
  ADD COLUMN "effectedAt" TIMESTAMPTZ(3),
  ADD COLUMN "effectedByUserId" UUID,
  ADD COLUMN "effectNote" TEXT;

UPDATE "privacy_requests"
   SET "identityVerifiedAt" = "receivedAt",
       "identityNote" = CASE WHEN "channel" = 'PORTAL' THEN 'Sesión de su portal' ELSE 'Registrada antes de que se pidiera acreditar la identidad' END
 WHERE "identityVerifiedAt" IS NULL;

ALTER TABLE "privacy_requests" ADD CONSTRAINT "privacy_requests_outcome_chk"
  CHECK ("outcome" IS NULL OR "outcome" IN ('GRANTED', 'DENIED'));
ALTER TABLE "privacy_requests" ADD CONSTRAINT "privacy_requests_consent_type_chk"
  CHECK ("consentType" IS NULL OR "consentType" IN ('PRIVACY_NOTICE', 'BIOMETRIC', 'RECURRING_CHARGE', 'MARKETING', 'HOUSE_RULES', 'HEALTH_DATA'));
-- Un resultado exige respuesta; hacerla efectiva exige que proceda.
ALTER TABLE "privacy_requests" ADD CONSTRAINT "privacy_requests_ciclo_chk"
  CHECK (("outcome" IS NULL OR "resolvedAt" IS NOT NULL) AND ("effectedAt" IS NULL OR "outcome" = 'GRANTED'));

-- La bandeja: lo que procede y falta hacer efectivo, por su segundo plazo.
CREATE INDEX "privacy_requests_organizationId_effectedAt_effectiveDueAt_idx"
  ON "privacy_requests"("organizationId", "effectedAt", "effectiveDueAt") WHERE "outcome" = 'GRANTED';

-- ── Textos de consentimiento: borradores que se corrigen y se borran (21-07) ──
-- Un borrador con un error obligaba a crear otra versión. Ahora se corrige o se
-- borra; lo publicado y lo retirado siguen intactos, y eso lo cuida la base:
--  · un texto RETIRADO tampoco se reescribe ni vuelve a publicarse (antes el
--    trigger solo cuidaba el PUBLICADO);
--  · solo se borra un BORRADOR.
CREATE OR REPLACE FUNCTION consent_document_immutable() RETURNS trigger AS $$
BEGIN
  IF OLD."status" = 'PUBLISHED' THEN
    IF NEW."bodyText" IS DISTINCT FROM OLD."bodyText"
       OR NEW."version" IS DISTINCT FROM OLD."version"
       OR NEW."consentType" IS DISTINCT FROM OLD."consentType"
       OR NEW."publishedAt" IS DISTINCT FROM OLD."publishedAt" THEN
      RAISE EXCEPTION 'consent_documents: un documento PUBLICADO es inmutable; publique una versión nueva';
    END IF;
    -- De publicado solo se sale hacia retirado.
    IF NEW."status" NOT IN ('PUBLISHED', 'RETIRED') THEN
      RAISE EXCEPTION 'consent_documents: un documento PUBLICADO no vuelve a borrador';
    END IF;
  ELSIF OLD."status" = 'RETIRED' THEN
    IF NEW."bodyText" IS DISTINCT FROM OLD."bodyText"
       OR NEW."version" IS DISTINCT FROM OLD."version"
       OR NEW."consentType" IS DISTINCT FROM OLD."consentType"
       OR NEW."publishedAt" IS DISTINCT FROM OLD."publishedAt"
       OR NEW."status" IS DISTINCT FROM OLD."status" THEN
      RAISE EXCEPTION 'consent_documents: un documento RETIRADO es inmutable; publique una versión nueva';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION consent_document_solo_borrador_se_borra() RETURNS trigger AS $$
BEGIN
  IF OLD."status" <> 'DRAFT' THEN
    RAISE EXCEPTION 'consent_documents: solo se borra un BORRADOR; lo publicado y lo retirado son evidencia';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER consent_document_solo_borrador_se_borra_trg
  BEFORE DELETE ON "consent_documents"
  FOR EACH ROW EXECUTE FUNCTION consent_document_solo_borrador_se_borra();

GRANT DELETE ON "consent_documents" TO gymflow_app;
