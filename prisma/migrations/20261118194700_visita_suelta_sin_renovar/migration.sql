-- 4-01 (auditoría 8, fase 0, contención): la visita suelta deja de renovarse
-- sola. Nacía con «se renueva sola» (el valor por omisión del catálogo) y esa
-- noche el job le emitía otra cuota: a los cinco días el visitante estaba
-- suspendido y debiendo. Desde ahora el servidor la vende sin renovación y
-- los jobs nunca la renuevan (vence esa noche); aquí se corrigen, una vez,
-- las que siguen vivas. Solo datos: el esquema no cambia, y no se borra ni se
-- condona nada (lo que ya deban lo decide la gerencia).
UPDATE "memberships" m
   SET "autoRenew" = false, "updatedAt" = now()
  FROM "plans" p
 WHERE p."id" = m."planId"
   AND p."organizationId" = m."organizationId"
   AND p."billingModel" = 'DAY_PASS'
   AND m."autoRenew" = true
   AND m."status" IN ('PENDING', 'TRIALING', 'ACTIVE', 'PAST_DUE', 'FROZEN', 'SUSPENDED');
