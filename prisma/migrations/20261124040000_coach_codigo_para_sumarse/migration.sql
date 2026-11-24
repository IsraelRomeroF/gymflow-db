-- COACH (auditoría 8, fase 3, bloque 3.8; decisiones D-28 y D-29).
-- Aditiva: ningún socio cambia de coach y ninguna clase cambia.
--
--  · `coach_link_codes`: el código de «Hacerme su coach» (D-29). El socio lo
--    genera en su teléfono y se lo dicta a su coach. Seis dígitos, un solo uso,
--    diez minutos. Solo se guarda su huella; `liveKey` existe mientras el código
--    está vivo y es única, así dos socios del mismo gimnasio nunca comparten uno.
--  · `coach_link_attempts`: cada vez que un coach teclea un código, para el
--    límite de intentos (cinco fallos en una hora lo dejan en espera).
--  · D-28: quien ya tenía encendido por persona «Gestionar clases y horarios»
--    conserva lo que hoy hace con una sesión (suplente y cupo), que ahora pide
--    `classes:session:operate`. Cancelar ya no se le da a nadie por persona.
--    Se puede correr dos veces.

-- CreateTable
CREATE TABLE "coach_link_codes" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "liveKey" TEXT,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "usedAt" TIMESTAMPTZ(3),
    "usedByUserId" UUID,
    "revokedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "coach_link_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "coach_link_attempts" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "succeeded" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "coach_link_attempts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "coach_link_codes_liveKey_key" ON "coach_link_codes"("liveKey");

-- CreateIndex
CREATE INDEX "coach_link_codes_organizationId_memberId_idx" ON "coach_link_codes"("organizationId", "memberId");

-- CreateIndex
CREATE INDEX "coach_link_attempts_organizationId_userId_createdAt_idx" ON "coach_link_attempts"("organizationId", "userId", "createdAt");

-- Un código usado o anulado ya no está vivo: no conserva su huella.
ALTER TABLE "coach_link_codes" ADD CONSTRAINT "coach_link_codes_live_chk"
  CHECK ("liveKey" IS NULL OR ("usedAt" IS NULL AND "revokedAt" IS NULL));

-- D-28: suplente y cupo para quien ya armaba el horario por persona.
UPDATE "users"
   SET "permissionOverrides" = jsonb_set(
         "permissionOverrides", '{add}',
         ("permissionOverrides"->'add') || '["classes:session:operate"]'::jsonb)
 WHERE jsonb_typeof("permissionOverrides"->'add') = 'array'
   AND "permissionOverrides"->'add' @> '["classes:manage"]'::jsonb
   AND NOT "permissionOverrides"->'add' @> '["classes:session:operate"]'::jsonb;
