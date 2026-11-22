-- Auditoría 8, fase 1, bloque 1.9 (cierre de mes). Aditivo.

-- QUIÉN FIRMÓ EL CIERRE (13-19, 14-04). La foto del mes decía quién la cerró
-- pero no quién la firmó: eso vivía solo en la bitácora. Ahora la fila lo
-- trae, y la lista de meses cerrados dice «cerró X · firmó Y» sin ir a buscar
-- el asiento. Null cuando cerró el dueño con su propia contraseña (sin
-- gerente, D-23).
ALTER TABLE "monthly_closes" ADD COLUMN "approvedByUserId" UUID;

-- Relleno de las fotos anteriores: la firma está en su asiento de bitácora.
UPDATE "monthly_closes" mc
   SET "approvedByUserId" = al."approvedByUserId"
  FROM "audit_logs" al
 WHERE al."organizationId" = mc."organizationId"
   AND al."action" = 'report.month.close'
   AND al."resourceId" = mc."id"
   AND al."approvedByUserId" IS NOT NULL
   AND mc."approvedByUserId" IS NULL;
