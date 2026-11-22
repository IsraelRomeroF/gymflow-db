-- UXA-01: un clic en "Entrada" llegaba dos veces (un efecto de React que corre
-- doble) y registraba dos asistencias, descontaba dos visitas o negaba el paso
-- con "Doble paso". Cada intento lleva su clave; el repetido es el mismo.
ALTER TABLE "access_decisions" ADD COLUMN "requestKey" TEXT;
CREATE UNIQUE INDEX "access_decisions_request_key" ON "access_decisions" ("organizationId", "requestKey")
  WHERE "requestKey" IS NOT NULL;
