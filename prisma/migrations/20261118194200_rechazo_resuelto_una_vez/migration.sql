-- 5-10 (auditoría 8, fase 0): un rechazo se resuelve UNA sola vez.
--
-- La concesión ("dejar pasar" o "cobrar y abrir") apunta al rechazo que
-- resuelve, y la unicidad impide una segunda concesión sobre el mismo
-- rechazo, también cuando dos personas la piden al mismo tiempo. Antes nada
-- lo impedía: dos "dejar pasar" eran dos asistencias y, con paquete, dos
-- visitas. Los NULL no chocan entre sí: solo cuentan las concesiones.
ALTER TABLE "access_decisions" ADD COLUMN "resolvesDecisionId" UUID;

CREATE UNIQUE INDEX "access_decisions_resolves_key"
  ON "access_decisions" ("resolvesDecisionId", "organizationId");

ALTER TABLE "access_decisions" ADD CONSTRAINT "decisions_resolves_same_org_fk"
  FOREIGN KEY ("resolvesDecisionId", "organizationId")
  REFERENCES "access_decisions"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Las concesiones anteriores se ligan a su rechazo con lo que dejó la
-- bitácora (`access.manual_grant` guarda `originalDecisionId`). Si un rechazo
-- se levantó más de una vez (el defecto que esto corrige), cuenta la primera.
-- La tabla es append-only por trigger: se apaga solo para este relleno único,
-- que no reescribe nada de lo que ya decía cada fila.
ALTER TABLE "access_decisions" DISABLE TRIGGER access_decisions_append_only;
UPDATE "access_decisions" c SET "resolvesDecisionId" = x.original
FROM (
  SELECT DISTINCT ON (o.id) o.id AS original, d.id AS concesion
  FROM (
    SELECT a."organizationId", a."resourceId",
           CASE WHEN (a."beforeState"->>'originalDecisionId') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                THEN (a."beforeState"->>'originalDecisionId')::uuid END AS original
    FROM "audit_logs" a
    WHERE a.action = 'access.manual_grant' AND a."resourceId" IS NOT NULL
  ) g
  JOIN "access_decisions" d ON d.id = g."resourceId" AND d."organizationId" = g."organizationId"
  JOIN "access_decisions" o ON o.id = g.original AND o."organizationId" = g."organizationId"
  WHERE d.outcome = 'GRANTED' AND o.outcome = 'DENIED'
  ORDER BY o.id, d.at, d.id
) x
WHERE c.id = x.concesion AND c."resolvesDecisionId" IS NULL;
ALTER TABLE "access_decisions" ENABLE TRIGGER access_decisions_append_only;
