-- Auditoría 8, fase 3, bloque 3.1 (D-01 y D-02). Todo es aditivo: no cambia
-- ni borra ninguna fila que ya exista.

-- 1) APODERADO TEMPORAL (D-02, opción b). El dueño nombra desde su teléfono a
--    UNA persona con fecha de fin; mientras el nombramiento esté vigente, esa
--    persona da la segunda firma a lo que piden los demás (nunca a lo suyo),
--    con la autoridad del dueño. Un nombramiento por fila; nunca se borra:
--    es la constancia de quién pudo firmar y de cuándo a cuándo.
--      · vigente = "endedAt" IS NULL y "endsAt" en el futuro;
--      · "endedAt"/"endReason": cuándo y por qué dejó de valer antes de leerse
--        como vencido (REVOKED lo revocó el dueño; EXPIRED llegó su fecha;
--        REPLACED el dueño nombró a otra persona).
CREATE TABLE "approval_proxies" (
  "id" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "grantedByUserId" UUID NOT NULL,
  "proxyUserId" UUID NOT NULL,
  "note" TEXT,
  "endsAt" TIMESTAMPTZ(3) NOT NULL,
  "endedAt" TIMESTAMPTZ(3),
  "endReason" TEXT,
  "endedByUserId" UUID,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "approval_proxies_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "approval_proxies" ADD CONSTRAINT "approval_proxies_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "approval_proxies" ADD CONSTRAINT "approval_proxies_grantedByUserId_fkey"
  FOREIGN KEY ("grantedByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "approval_proxies" ADD CONSTRAINT "approval_proxies_proxyUserId_fkey"
  FOREIGN KEY ("proxyUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- Nadie se nombra a sí mismo; la fecha de fin es posterior al nombramiento;
-- lo que terminó dice por qué, y lo que no ha terminado no lo dice.
ALTER TABLE "approval_proxies" ADD CONSTRAINT "approval_proxies_otra_persona_chk" CHECK ("proxyUserId" <> "grantedByUserId");
ALTER TABLE "approval_proxies" ADD CONSTRAINT "approval_proxies_fin_chk" CHECK ("endsAt" > "createdAt");
ALTER TABLE "approval_proxies" ADD CONSTRAINT "approval_proxies_endReason_chk"
  CHECK (("endedAt" IS NULL AND "endReason" IS NULL) OR ("endedAt" IS NOT NULL AND "endReason" IN ('REVOKED', 'EXPIRED', 'REPLACED')));
-- UNO SOLO a la vez por gimnasio: la base no deja dos nombramientos abiertos.
CREATE UNIQUE INDEX "approval_proxies_uno_abierto_key" ON "approval_proxies"("organizationId") WHERE "endedAt" IS NULL;
CREATE INDEX "approval_proxies_organizationId_createdAt_idx" ON "approval_proxies"("organizationId", "createdAt");
CREATE INDEX "approval_proxies_proxyUserId_idx" ON "approval_proxies"("proxyUserId");
REVOKE DELETE ON "approval_proxies" FROM gymflow_app;

-- «FIRMÓ COMO APODERADO»: la firma emitida y la solicitud contestada apuntan
-- al nombramiento con el que se dieron. NULL = la dio el dueño (todo lo
-- anterior a esta migración).
ALTER TABLE "approval_grants" ADD COLUMN "proxyId" UUID;
ALTER TABLE "approval_grants" ADD CONSTRAINT "approval_grants_proxyId_fkey"
  FOREIGN KEY ("proxyId") REFERENCES "approval_proxies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "approval_requests" ADD COLUMN "proxyId" UUID;
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_proxyId_fkey"
  FOREIGN KEY ("proxyId") REFERENCES "approval_proxies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- 2) EQUIPO CONOCIDO (D-01: el límite de intentos es por persona, no por red).
--    Con la dirección fija cualquiera puede teclear mal cinco veces la
--    contraseña de la dueña y bloquearle la cuenta. Hasta hoy el titular
--    pasaba ese bloqueo solo desde una IP en la que ya había entrado; en un
--    teléfono con datos la IP cambia cada rato. Ahora también pasa desde un
--    EQUIPO en el que ya entró con esa cuenta: el navegador guarda una llave
--    al azar (cookie) y aquí queda solo su sha256. Sirve únicamente junto con
--    la contraseña correcta.
CREATE TABLE "known_devices" (
  "id" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "keyHash" TEXT NOT NULL,
  "label" TEXT,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastUsedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "known_devices_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "known_devices" ADD CONSTRAINT "known_devices_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
CREATE UNIQUE INDEX "known_devices_userId_keyHash_key" ON "known_devices"("userId", "keyHash");
