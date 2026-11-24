-- Fase 3 · bloque 3.4 · Altas (auditoría 8): D-09 celular compartido con
-- responsable, D-10 menores de 15 a 17 con tutor.
--
-- Se puede correr dos veces sin daño (IF EXISTS / IF NOT EXISTS).

-- ── D-09 · dos socios pueden compartir celular ──────────────────────────────
-- El celular deja de ser único por gimnasio: mamá e hija, hermanos. Es la
-- única migración de la reestructura que QUITA una garantía de la base; la
-- regla que la sustituye vive en el servicio de socios (compartir exige anotar
-- quién responde por el número) y en `core/identity.ts` (el celular solo nunca
-- une a dos personas). Queda un índice normal, que solo sirve para buscar.
DROP INDEX IF EXISTS "members_org_phone_active_key";
CREATE INDEX IF NOT EXISTS "members_org_phone_idx" ON "members" ("organizationId", "phoneE164");

-- El responsable: del celular que se comparte y, si el socio es menor, su
-- tutor. SELF = el número es suyo · MEMBER = es de otro socio · ADULT = es de
-- un adulto que no es socio (nombre y, si es otro, su teléfono).
ALTER TABLE "members"
  ADD COLUMN IF NOT EXISTS "responsibleKind" TEXT,
  ADD COLUMN IF NOT EXISTS "responsibleMemberId" UUID,
  ADD COLUMN IF NOT EXISTS "responsibleName" TEXT,
  ADD COLUMN IF NOT EXISTS "responsiblePhoneE164" TEXT,
  ADD COLUMN IF NOT EXISTS "guardianSignedAt" TIMESTAMPTZ(3);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'members_responsible_kind_check') THEN
    ALTER TABLE "members" ADD CONSTRAINT "members_responsible_kind_check" CHECK (
      "responsibleKind" IS NULL
      OR ("responsibleKind" = 'SELF' AND "responsibleMemberId" IS NULL)
      OR ("responsibleKind" = 'MEMBER' AND "responsibleMemberId" IS NOT NULL AND "responsibleMemberId" <> "id")
      OR ("responsibleKind" = 'ADULT' AND "responsibleMemberId" IS NULL AND "responsibleName" IS NOT NULL)
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'members_responsible_same_org_fk') THEN
    ALTER TABLE "members" ADD CONSTRAINT "members_responsible_same_org_fk"
      FOREIGN KEY ("responsibleMemberId", "organizationId") REFERENCES "members" ("id", "organizationId")
      ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "members_responsible_member_idx" ON "members" ("organizationId", "responsibleMemberId");

-- ── D-10 · menores de 15 a 17 por QR ────────────────────────────────────────
-- El menor escribe quién es su tutor y a qué celular se le llama. El alta
-- sigue SUBMITTED («falta su tutor» se deriva de su edad) y se aprueba cuando
-- el tutor firma en el mostrador.
ALTER TABLE "member_intakes"
  ADD COLUMN IF NOT EXISTS "guardianName" TEXT,
  ADD COLUMN IF NOT EXISTS "guardianPhoneE164" TEXT;

-- La aceptación del tutor es un consentimiento A SU NOMBRE: quién firmó por el
-- socio. El trigger `member_consents_immutable` y el UPDATE recortado a
-- `revokedAt` (20260930180000) ya impiden cambiarlas después.
ALTER TABLE "member_consents"
  ADD COLUMN IF NOT EXISTS "signedByName" TEXT,
  ADD COLUMN IF NOT EXISTS "signedByPhoneE164" TEXT;
