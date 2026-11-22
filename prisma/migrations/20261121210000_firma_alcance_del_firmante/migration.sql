-- Auditoría 8, fase 2, bloque 2.10 (firma a distancia). Todo es aditivo.

-- SE SABE SI QUIEN FIRMA LA PUDO VER (29-05). Hasta hoy una solicitud que
-- vencía decía «nadie la contestó» y el mostrador no sabía si insistir,
-- llamar o esperar. La solicitud guarda ahora:
--   · "notifiedCount": a cuántos teléfonos salió el aviso al pedirla;
--   · "deliveredAt":   cuándo salió ese aviso (NULL si no salió ninguno);
--   · "seenAt":        la primera vez que la bandeja de alguien que puede
--                      firmarla la mostró.
-- Las solicitudes anteriores quedan con 0 y NULL: «no se sabe» se lee igual
-- que «no la vio», que es lo que la pantalla decía de todas.
ALTER TABLE "approval_requests"
  ADD COLUMN "notifiedCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "deliveredAt" TIMESTAMPTZ(3),
  ADD COLUMN "seenAt" TIMESTAMPTZ(3);
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_notifiedCount_chk" CHECK ("notifiedCount" >= 0);

-- «RESUELTAS HOY» (20-05): las solicitudes del último día, la más reciente
-- primero. El índice que había sirve a las pendientes (estado + vencimiento).
CREATE INDEX "approval_requests_organizationId_createdAt_idx" ON "approval_requests"("organizationId", "createdAt");
