-- ENTRADA: REENTRADA DEL DÍA Y PASE DE PRUEBA (auditoría 8, fase 3, bloque 3.3; D-07 y D-08).
-- Aditiva y segura con datos reales: una columna con valor por omisión y una
-- tabla nueva. No reescribe ni borra nada de lo que ya existe.

-- D-07 · Una entrada por día y sucursal. La segunda vez que alguien pasa el
-- mismo día por la misma sede se registra la decisión (queda quién, cuándo y
-- por dónde), pero NO nace otra asistencia ni se descuenta otra visita del
-- paquete: es una reentrada. La columna lo dice sin tener que deducirlo de
-- «una decisión concedida sin asistencia».
--
-- Las decisiones anteriores quedan en `false`: con la regla de entonces cada
-- paso contaba, y la historia no se reescribe (las asistencias y las visitas
-- ya descontadas se quedan como están).
ALTER TABLE "access_decisions" ADD COLUMN "reentry" BOOLEAN NOT NULL DEFAULT false;

-- D-08 · Pase de prueba: gratis, UNO por persona, identificada por su celular.
-- No es un cargo (no mueve dinero) ni una membresía: es el permiso de entrar
-- un día a una sede. La entrada misma queda en `access_decisions` y
-- `attendance_events`, como la de cualquiera.
--
-- El celular no se guarda: se guarda su huella (SHA-256 con el gimnasio) y sus
-- últimos cuatro dígitos para decirle a recepción con cuál se identificó. Así
-- el «uno por celular» sobrevive a que el socio cambie de número en su ficha o
-- a que se anonimice, sin dejar aquí un dato personal que borrar después.
CREATE TABLE "trial_passes" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "branchId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    -- Huella del celular: sha256(<organizationId>:<diez dígitos>).
    "phoneKey" TEXT NOT NULL,
    "phoneLast4" TEXT NOT NULL,
    -- El día de operación (de la sede) en que vale.
    "validOn" DATE NOT NULL,
    "grantedByUserId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "trial_passes_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "trial_passes_last4_check" CHECK ("phoneLast4" ~ '^[0-9]{4}$')
);
-- Uno por celular y uno por persona, en todo el gimnasio (no por sucursal).
CREATE UNIQUE INDEX "trial_passes_org_phone_key" ON "trial_passes"("organizationId", "phoneKey");
CREATE UNIQUE INDEX "trial_passes_org_member_key" ON "trial_passes"("organizationId", "memberId");
CREATE INDEX "trial_passes_org_branch_day_idx" ON "trial_passes"("organizationId", "branchId", "validOn");
ALTER TABLE "trial_passes" ADD CONSTRAINT "trial_passes_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "trial_passes" ADD CONSTRAINT "trial_passes_branch_same_org_fk"
  FOREIGN KEY ("branchId", "organizationId") REFERENCES "branches"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "trial_passes" ADD CONSTRAINT "trial_passes_member_same_org_fk"
  FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;
