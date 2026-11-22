-- Auditoría 8, fase 0, bloque 0.9 (firmas). Todo es aditivo.

-- 1) ESCALERA DE FALLOS DE LA FIRMA, aparte del inicio de sesión (24-11,
--    D24-04). Hasta hoy, equivocarse al firmar sumaba intentos fallidos a la
--    CUENTA de quien firma y la bloqueaba hasta 30 minutos, también para
--    entrar al panel; cualquiera en el mostrador podía provocarlo. La firma
--    lleva ahora su propio contador: al 3.er fallo en 10 minutos se avisa al
--    firmante y al 5.º sus firmas quedan en pausa 10 minutos. El inicio de
--    sesión no se toca. Una fila por persona que alguna vez falló una firma;
--    el contador vuelve a cero con UPDATE, nunca se borra.
CREATE TABLE "approval_signer_locks" (
  "userId" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "failedCount" INTEGER NOT NULL DEFAULT 0,
  "windowStartedAt" TIMESTAMPTZ(3),
  "pausedUntil" TIMESTAMPTZ(3),
  "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "approval_signer_locks_pkey" PRIMARY KEY ("userId")
);
CREATE INDEX "approval_signer_locks_organizationId_idx" ON "approval_signer_locks"("organizationId");
ALTER TABLE "approval_signer_locks" ADD CONSTRAINT "approval_signer_locks_failedCount_chk" CHECK ("failedCount" >= 0);
REVOKE DELETE ON "approval_signer_locks" FROM gymflow_app;

-- 2) LA FIRMA SE ENTREGA MIENTRAS NO SE USE (29-03). La solicitud aprobada
--    apunta a la firma que emitió: así se sabe si ya se usó o venció, y el
--    token cifrado se borra solo entonces. Antes se entregaba UNA vez y, si
--    se perdía esa respuesta, el mostrador leía «nadie la contestó».
ALTER TABLE "approval_requests" ADD COLUMN "grantId" UUID;

-- 3) DE QUÉ SE TRATA (29-01), relleno de las solicitudes viejas: el tipo de
--    registro sale de su permiso. La condonación es del adeudo de una
--    membresía si el id es de una membresía; si no, de un cargo. Lo que no
--    se reconoce se queda como estaba.
UPDATE "approval_requests" r SET "resourceType" = CASE
    WHEN r."permission" = 'cash:withdraw' THEN 'CashSession'
    WHEN r."permission" IN ('payments:reverse', 'payments:refund') THEN 'Payment'
    WHEN r."permission" IN ('billing:charge:void', 'billing:discount:apply') THEN 'Charge'
    WHEN r."permission" = 'billing:waiver:apply' THEN
      CASE WHEN EXISTS (SELECT 1 FROM "memberships" m WHERE m."id" = r."resourceId" AND m."organizationId" = r."organizationId")
           THEN 'Membership' ELSE 'Charge' END
    WHEN r."permission" IN ('members:anonymize', 'members:balance:adjust') THEN 'Member'
    WHEN r."permission" = 'memberships:visitpack:adjust' THEN 'VisitPack'
    WHEN r."permission" = 'reports:month:close' THEN 'MonthlyClose'
  END
 WHERE r."resourceType" IS NULL
   AND r."permission" IN ('cash:withdraw', 'payments:reverse', 'payments:refund', 'billing:charge:void', 'billing:discount:apply',
                          'billing:waiver:apply', 'members:anonymize', 'members:balance:adjust', 'memberships:visitpack:adjust', 'reports:month:close');
