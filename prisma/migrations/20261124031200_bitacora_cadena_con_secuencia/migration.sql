-- Auditoría 8, fase 3, bloque 3.12: LA CADENA DE LA BITÁCORA DEJA DE DEPENDER
-- DEL RELOJ DEL SERVIDOR. Todo es aditivo y no toca ninguna fila existente.
--
-- Hasta hoy «el último asiento» (con el que se enlaza el siguiente) y el orden
-- en que se verifica la cadena se decidían por la hora del servidor (`at`) y,
-- dentro del mismo milisegundo, por el id. Si el reloj retrocedía (una
-- corrección de hora) dos asientos se enlazaban con el mismo anterior y la
-- verificación daba la cadena por rota sin que nadie la hubiera tocado.
--
-- `chainSeq` es el número de eslabón: 1, 2, 3… por organización (y uno solo
-- para la cadena de plataforma). Lo pone la aplicación bajo el mismo candado
-- con que ya serializa la escritura. El índice único hace imposible que dos
-- asientos ocupen el mismo lugar de la cadena.
--
-- LO YA ASENTADO queda con `chainSeq` NULL (las tablas son solo-agregar: no se
-- edita ninguna fila). Se sigue verificando exactamente como antes, por
-- (`at`, `id`), y va ANTES de todo lo numerado; el primer asiento numerado se
-- enlaza con la punta de ese tramo.
ALTER TABLE "audit_logs" ADD COLUMN "chainSeq" INTEGER;
CREATE UNIQUE INDEX "audit_logs_organizationId_chainSeq_key" ON "audit_logs"("organizationId", "chainSeq");

ALTER TABLE "platform_audit_logs" ADD COLUMN "chainSeq" INTEGER;
CREATE UNIQUE INDEX "platform_audit_logs_chainSeq_key" ON "platform_audit_logs"("chainSeq");
