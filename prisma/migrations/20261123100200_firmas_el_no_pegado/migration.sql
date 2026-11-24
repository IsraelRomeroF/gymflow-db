-- Auditoría 8, fase 3, bloque 3.2 (firmas, D-03 opción b). Todo es aditivo.

-- EL «NO» QUEDA PEGADO A LA OPERACIÓN. Hasta hoy un rechazo solo cerraba esa
-- solicitud: se podía volver a pedir lo mismo al instante y sin límite. Ahora
-- la solicitud que vuelve a pedir una operación rechazada guarda:
--   · "previousRequestId": la solicitud rechazada a la que responde;
--   · "reply":             lo que quien pide le contesta a ese «no»
--                          (obligatorio para volver a pedir).
-- «PREGUNTAR» EN VEZ DE RECHAZAR. Quien firma puede preguntar y la solicitud
-- sigue pendiente (no es un estado nuevo: el CHECK de cinco estados no cambia):
--   · "question", "questionAt", "questionByUserId": qué preguntó, cuándo y quién;
--   · "answer", "answeredAt": lo que contestó quien pidió.
-- Las solicitudes anteriores quedan con NULL en todo: se leen como hasta hoy.
ALTER TABLE "approval_requests"
  ADD COLUMN "previousRequestId" UUID,
  ADD COLUMN "reply" TEXT,
  ADD COLUMN "question" TEXT,
  ADD COLUMN "questionAt" TIMESTAMPTZ(3),
  ADD COLUMN "questionByUserId" UUID,
  ADD COLUMN "answer" TEXT,
  ADD COLUMN "answeredAt" TIMESTAMPTZ(3);

ALTER TABLE "approval_requests"
  ADD CONSTRAINT "approval_requests_previousRequestId_fkey"
  FOREIGN KEY ("previousRequestId") REFERENCES "approval_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Una pregunta lleva su hora y su autor; una contestación, su pregunta y su hora.
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_question_chk"
  CHECK (("question" IS NULL) = ("questionAt" IS NULL) AND ("question" IS NULL) = ("questionByUserId" IS NULL));
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_answer_chk"
  CHECK (("answer" IS NULL) = ("answeredAt" IS NULL) AND ("answer" IS NULL OR "question" IS NOT NULL));

-- Para buscar el «no» anterior de una operación y contar cuántas veces se
-- pidió en la última hora: mismo permiso y mismo registro, lo pida quien lo pida.
CREATE INDEX "approval_requests_operacion_idx" ON "approval_requests"("organizationId", "permission", "resourceId", "createdAt");
