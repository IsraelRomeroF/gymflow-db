-- CONSERVACIÓN DE DATOS (auditoría 8, fase 3, bloque 3.9; D-32). Aditiva: tres
-- tablas nuevas; no toca ninguna fila existente.
--
--  · El rostro de quien se da de baja se borra a los 30 días si no regresa.
--  · Los demás datos se anonimizan a los 24 meses de la baja (plazo por
--    gimnasio), pero nadie se anonimiza solo: cada mes se arma una lista y la
--    firma el dueño. Una firma por lista.

-- ── Cuándo empezó a correr la regla en cada gimnasio ────────────────────────
-- La escribe la primera pasada del cierre diario. Para quien se dio de baja
-- ANTES de ese día, los 30 días del rostro cuentan desde aquí: la primera
-- noche no borra nada. Una fila por gimnasio, que no se mueve ni se borra.
CREATE TABLE "privacy_conservation_starts" (
  "organizationId" UUID NOT NULL,
  "startedOn" DATE NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "privacy_conservation_starts_pkey" PRIMARY KEY ("organizationId")
);
ALTER TABLE "privacy_conservation_starts" ADD CONSTRAINT "privacy_conservation_starts_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT ON "privacy_conservation_starts" TO gymflow_app;
REVOKE UPDATE, DELETE ON "privacy_conservation_starts" FROM gymflow_app;

-- ── La lista mensual ────────────────────────────────────────────────────────
-- PENDING  espera la firma (a lo más una por gimnasio);
-- SIGNED   firmada: lo listado se anonimiza al amparo de esa firma;
-- REPLACED nadie la firmó y la del mes siguiente la reemplazó (no borró nada).
CREATE TABLE "privacy_batches" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "period" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "monthsAfterArchive" INTEGER NOT NULL,
  "cutoffOn" DATE NOT NULL,
  "preparedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "signedAt" TIMESTAMPTZ(3),
  "signedByUserId" UUID,
  "closedAt" TIMESTAMPTZ(3),
  CONSTRAINT "privacy_batches_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "privacy_batches_period_chk" CHECK ("period" ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  CONSTRAINT "privacy_batches_status_chk" CHECK ("status" IN ('PENDING', 'SIGNED', 'REPLACED')),
  CONSTRAINT "privacy_batches_months_chk" CHECK ("monthsAfterArchive" BETWEEN 1 AND 120),
  -- Firmada = con fecha y con quién. Ni firma sin estado, ni estado sin firma.
  CONSTRAINT "privacy_batches_firma_chk" CHECK (("status" = 'SIGNED') = ("signedAt" IS NOT NULL AND "signedByUserId" IS NOT NULL)),
  CONSTRAINT "privacy_batches_firmante_chk" CHECK (("signedAt" IS NULL) = ("signedByUserId" IS NULL))
);
-- Una lista por mes y gimnasio; y a lo más una en espera de firma.
CREATE UNIQUE INDEX "privacy_batches_org_period_key" ON "privacy_batches"("organizationId", "period");
CREATE UNIQUE INDEX "privacy_batches_una_pendiente" ON "privacy_batches"("organizationId") WHERE "status" = 'PENDING';
CREATE UNIQUE INDEX "privacy_batches_id_org_key" ON "privacy_batches"("id", "organizationId");
ALTER TABLE "privacy_batches" ADD CONSTRAINT "privacy_batches_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "privacy_batches" ADD CONSTRAINT "privacy_batches_signedByUserId_fkey" FOREIGN KEY ("signedByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Lo firmado no se desfirma ni se reescribe; lo reemplazado no revive.
CREATE OR REPLACE FUNCTION privacy_batches_firma() RETURNS trigger AS $$
BEGIN
  IF OLD."status" <> 'PENDING' AND NEW."status" IS DISTINCT FROM OLD."status" THEN
    RAISE EXCEPTION 'privacy_batches: una lista firmada o reemplazada no cambia de estado';
  END IF;
  IF NEW."organizationId" IS DISTINCT FROM OLD."organizationId"
     OR NEW."period" IS DISTINCT FROM OLD."period"
     OR NEW."cutoffOn" IS DISTINCT FROM OLD."cutoffOn"
     OR NEW."monthsAfterArchive" IS DISTINCT FROM OLD."monthsAfterArchive"
     OR NEW."preparedAt" IS DISTINCT FROM OLD."preparedAt" THEN
    RAISE EXCEPTION 'privacy_batches: el mes, el corte y el plazo de una lista no se cambian';
  END IF;
  IF OLD."signedAt" IS NOT NULL AND (NEW."signedAt" IS DISTINCT FROM OLD."signedAt" OR NEW."signedByUserId" IS DISTINCT FROM OLD."signedByUserId") THEN
    RAISE EXCEPTION 'privacy_batches: la firma de una lista no se cambia';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER privacy_batches_firma_trg
  BEFORE UPDATE ON "privacy_batches"
  FOR EACH ROW EXECUTE FUNCTION privacy_batches_firma();

GRANT SELECT, INSERT, UPDATE ON "privacy_batches" TO gymflow_app;
REVOKE DELETE ON "privacy_batches" FROM gymflow_app;

-- ── Los exsocios de cada lista ──────────────────────────────────────────────
-- No guarda nombre ni teléfono: se leen de la ficha mientras existan. Guarda el
-- código (que al anonimizar ya no dice quién es) y el instante de la baja con
-- la que entró: si regresó y se volvió a ir, esa baja ya es otra y no se toca.
-- LISTED en la lista · ANONYMIZED hecho · EXCLUDED la gerencia lo sacó con
-- motivo · SKIPPED al ejecutar ya no cumplía (regresó, ya anonimizado, plazo).
CREATE TABLE "privacy_batch_items" (
  "id" UUID NOT NULL,
  "batchId" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "memberId" UUID NOT NULL,
  "memberCode" TEXT NOT NULL,
  "archivedAt" TIMESTAMPTZ(3) NOT NULL,
  "archivedOn" DATE NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'LISTED',
  "note" TEXT,
  "resolvedAt" TIMESTAMPTZ(3),
  "resolvedByUserId" UUID,
  CONSTRAINT "privacy_batch_items_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "privacy_batch_items_status_chk" CHECK ("status" IN ('LISTED', 'ANONYMIZED', 'EXCLUDED', 'SKIPPED')),
  CONSTRAINT "privacy_batch_items_resuelto_chk" CHECK (("status" = 'LISTED') = ("resolvedAt" IS NULL)),
  -- Sacar a alguien de la lista, o no tocarlo, dice por qué.
  CONSTRAINT "privacy_batch_items_motivo_chk" CHECK ("status" NOT IN ('EXCLUDED', 'SKIPPED') OR "note" IS NOT NULL)
);
CREATE UNIQUE INDEX "privacy_batch_items_batch_member_key" ON "privacy_batch_items"("batchId", "memberId");
CREATE INDEX "privacy_batch_items_org_member_idx" ON "privacy_batch_items"("organizationId", "memberId");
ALTER TABLE "privacy_batch_items" ADD CONSTRAINT "privacy_batch_items_batch_same_org_fk" FOREIGN KEY ("batchId", "organizationId") REFERENCES "privacy_batches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "privacy_batch_items" ADD CONSTRAINT "privacy_batch_items_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE CASCADE ON UPDATE CASCADE;

-- LA GARANTÍA DE D-32: nadie pasa a ANONYMIZED si su lista no está firmada, y
-- una lista solo crece mientras espera la firma (lo que el dueño firma es lo
-- que vio). Lo ya resuelto no se reescribe.
CREATE OR REPLACE FUNCTION privacy_batch_items_firma() RETURNS trigger AS $$
DECLARE
  estado TEXT;
BEGIN
  SELECT "status" INTO estado FROM "privacy_batches" WHERE "id" = NEW."batchId";
  IF TG_OP = 'INSERT' THEN
    IF NEW."status" <> 'LISTED' THEN
      RAISE EXCEPTION 'privacy_batch_items: un renglón nace en la lista (LISTED)';
    END IF;
    IF estado IS DISTINCT FROM 'PENDING' THEN
      RAISE EXCEPTION 'privacy_batch_items: a una lista firmada o reemplazada no se le agrega nadie';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD."status" <> 'LISTED' THEN
    RAISE EXCEPTION 'privacy_batch_items: un renglón ya resuelto no se cambia';
  END IF;
  IF NEW."batchId" IS DISTINCT FROM OLD."batchId" OR NEW."memberId" IS DISTINCT FROM OLD."memberId"
     OR NEW."organizationId" IS DISTINCT FROM OLD."organizationId" OR NEW."archivedAt" IS DISTINCT FROM OLD."archivedAt" THEN
    RAISE EXCEPTION 'privacy_batch_items: de quién es el renglón no se cambia';
  END IF;
  IF NEW."status" IN ('ANONYMIZED', 'SKIPPED') AND estado IS DISTINCT FROM 'SIGNED' THEN
    RAISE EXCEPTION 'privacy_batch_items: nadie se anonimiza sin la firma de su lista';
  END IF;
  IF NEW."status" = 'EXCLUDED' AND estado IS DISTINCT FROM 'PENDING' THEN
    RAISE EXCEPTION 'privacy_batch_items: de una lista ya firmada no se saca a nadie';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER privacy_batch_items_firma_trg
  BEFORE INSERT OR UPDATE ON "privacy_batch_items"
  FOR EACH ROW EXECUTE FUNCTION privacy_batch_items_firma();

GRANT SELECT, INSERT, UPDATE ON "privacy_batch_items" TO gymflow_app;
REVOKE DELETE ON "privacy_batch_items" FROM gymflow_app;
