-- MEDICIÓN DEL RECONOCIMIENTO FACIAL (auditoría 8, fase 2, bloque 2.3; hallazgo 6-10).
-- Aditiva y segura con datos reales: solo agrega una tabla.
--
-- Antes de fijar el umbral con el que la Estación reconoce, se mide con socios
-- reales («es») y con personas que no son socios («no es»). Cada intento
-- guarda SOLO parecidos (números entre -1 y 1): nunca la foto ni la plantilla.
-- Un intento mal tomado se puede borrar; la tabla no es un libro.
CREATE TABLE "face_measurements" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    -- MEMBER: un socio con rostro registrado. STRANGER: alguien que no es socio.
    "kind" TEXT NOT NULL,
    "memberId" UUID,
    -- Parecido con su propio rostro registrado (solo MEMBER).
    "ownScore" DOUBLE PRECISION,
    -- El mayor parecido con el rostro de cualquier otra persona del padrón.
    "bestOtherScore" DOUBLE PRECISION,
    "compared" INTEGER NOT NULL DEFAULT 0,
    "recordedByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "face_measurements_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "face_measurements_kind_check" CHECK ("kind" IN ('MEMBER', 'STRANGER')),
    CONSTRAINT "face_measurements_member_check" CHECK (("kind" = 'MEMBER') = ("memberId" IS NOT NULL))
);
CREATE INDEX "face_measurements_org_created_idx" ON "face_measurements"("organizationId", "createdAt");
ALTER TABLE "face_measurements" ADD CONSTRAINT "face_measurements_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
