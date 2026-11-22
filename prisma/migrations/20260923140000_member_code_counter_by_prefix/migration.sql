-- El contador de códigos de socio pasa de estar indexado por SUCURSAL a
-- estarlo por PREFIJO.
--
-- El código es `PREFIJO-NNNNN` y su unicidad es `(organización, código)`. Con
-- el contador por sucursal había dos formas de chocar:
--   1. Dos sedes que comparten las tres primeras letras ("Polanco" y "Polanco
--      Norte") arrancaban las dos en 1 y emitían ambas `POL-00001`.
--   2. Archivar una sede y reutilizar su prefijo reiniciaba el contador, que
--      volvía a chocar con los códigos que esa sede ya había emitido.
-- El contador tiene que vivir en el mismo espacio que la unicidad que protege.

ALTER TABLE "member_code_counters" ADD COLUMN "prefix" VARCHAR(3);

-- Se rellena desde el código de la sucursal, INCLUIDAS las archivadas: sus
-- socios siguen existiendo y sus códigos siguen ocupados.
UPDATE "member_code_counters" c
SET "prefix" = upper(left(b."code", 3))
FROM "branches" b
WHERE b."id" = c."branchId";

-- Una fila sin sucursal correspondiente no puede conservarse: no hay prefijo
-- que asignarle, y dejarla rompería la clave primaria nueva.
DELETE FROM "member_code_counters" WHERE "prefix" IS NULL;

-- Al colapsar varias sucursales en un mismo prefijo hay que quedarse con el
-- mayor. Se recalcula además contra los códigos REALMENTE emitidos, que es la
-- única fuente fiable: un contador por debajo del máximo emitido produciría
-- colisiones desde el primer alta.
CREATE TEMP TABLE _counter_fix AS
SELECT c."organizationId",
       c."prefix",
       GREATEST(
         MAX(c."lastSequence"),
         COALESCE((
           SELECT MAX(split_part(m."memberCode", '-', 2)::int)
           FROM "members" m
           WHERE m."organizationId" = c."organizationId"
             AND m."memberCode" ~ ('^' || c."prefix" || '-[0-9]{1,6}$')
         ), 0)
       ) AS "lastSequence"
FROM "member_code_counters" c
GROUP BY c."organizationId", c."prefix";

DELETE FROM "member_code_counters";

ALTER TABLE "member_code_counters" DROP CONSTRAINT "member_code_counters_pkey";
ALTER TABLE "member_code_counters" DROP COLUMN "branchId";
ALTER TABLE "member_code_counters" ALTER COLUMN "prefix" SET NOT NULL;
ALTER TABLE "member_code_counters" ADD CONSTRAINT "member_code_counters_pkey"
  PRIMARY KEY ("organizationId", "prefix");

INSERT INTO "member_code_counters" ("organizationId", "prefix", "lastSequence", "updatedAt")
SELECT "organizationId", "prefix", "lastSequence", now() FROM _counter_fix;

DROP TABLE _counter_fix;

GRANT SELECT, INSERT, UPDATE, DELETE ON "member_code_counters" TO gymflow_app;
