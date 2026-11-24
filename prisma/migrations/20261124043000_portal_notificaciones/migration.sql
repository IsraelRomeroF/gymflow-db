-- PORTAL DEL SOCIO (auditoría 8, fase 3, bloque 3.10; decisiones D-34 y D-32).
-- Aditiva: ningún socio cambia de plan, de acceso ni de saldo.
--
--  · `member_push_subscriptions`: el teléfono del socio que encendió las
--    notificaciones (D-34 c: gratis, del navegador, con llaves propias del
--    servidor; ningún proveedor contratado). Una fila por navegador: el
--    `endpoint` es único en el mundo, así un teléfono solo recibe los avisos
--    de UN socio (el último que las encendió ahí, D-09). Va atada a la sesión
--    del portal de ese teléfono: cerrada la sesión, la fila se va con ella.
--  · `member_notification_preferences`: de qué quiere que se le notifique
--    (pagos, clases). Sin fila, todo encendido.
--  · Los mensajes ya mandados a exsocios que YA están anonimizados dejan de
--    traer su nombre (`outbound_messages.body`). Se puede correr dos veces.

-- CreateTable
CREATE TABLE "member_push_subscriptions" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "sessionId" UUID NOT NULL,
    "endpoint" TEXT NOT NULL,
    "p256dh" TEXT NOT NULL,
    "auth" TEXT NOT NULL,
    "userAgent" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastUsedAt" TIMESTAMPTZ(3),

    CONSTRAINT "member_push_subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_notification_preferences" (
    "memberId" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "payments" BOOLEAN NOT NULL DEFAULT true,
    "classes" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_notification_preferences_pkey" PRIMARY KEY ("memberId")
);

-- CreateIndex
CREATE UNIQUE INDEX "member_push_subscriptions_endpoint_key" ON "member_push_subscriptions"("endpoint");
CREATE INDEX "member_push_subscriptions_org_member_idx" ON "member_push_subscriptions"("organizationId", "memberId");
CREATE INDEX "member_push_subscriptions_session_idx" ON "member_push_subscriptions"("sessionId");

-- AddForeignKey
ALTER TABLE "member_push_subscriptions" ADD CONSTRAINT "member_push_subscriptions_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "member_push_subscriptions" ADD CONSTRAINT "member_push_subscriptions_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "member_push_subscriptions" ADD CONSTRAINT "member_push_subscriptions_session_fkey" FOREIGN KEY ("sessionId") REFERENCES "member_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "member_notification_preferences" ADD CONSTRAINT "member_notification_preferences_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "member_notification_preferences" ADD CONSTRAINT "member_notification_preferences_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE CASCADE ON UPDATE CASCADE;

-- La aplicación las lee, las crea, las cambia y las borra (apagar es borrar la fila).
GRANT SELECT, INSERT, UPDATE, DELETE ON "member_push_subscriptions" TO gymflow_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON "member_notification_preferences" TO gymflow_app;

-- Lo que ya existe: el texto de los mensajes mandados a quien ya fue
-- anonimizado llevaba su nombre («Hola Ana, te escribimos de…»). Queda la fila
-- (quién lo mandó y cuándo) y se va el texto. Desde ahora lo hace la
-- anonimización en el mismo acto (`OutboundRepository.olvidarTextos`).
UPDATE "outbound_messages" o
   SET "body" = 'Texto retirado: el socio fue anonimizado.'
  FROM "members" m
 WHERE m."id" = o."memberId" AND m."organizationId" = o."organizationId"
   AND m."anonymizedAt" IS NOT NULL
   AND o."body" IS NOT NULL AND o."body" <> 'Texto retirado: el socio fue anonimizado.';
