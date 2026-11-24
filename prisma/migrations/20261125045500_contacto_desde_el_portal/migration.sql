-- EL SOCIO CAMBIA SUS DATOS DE CONTACTO DESDE EL PORTAL (auditoría 8, fase 4,
-- bloque 4.8; decisión D-36, opción c: «todo directo, incluido el celular»).
-- Aditiva: una tabla nueva y vacía. No escribe en ninguna fila que ya exista.
--
--  · `member_contact_changes`: una fila por dato que el socio cambió desde su
--    teléfono (celular, correo, nombre o teléfono de su contacto de
--    emergencia), con el valor de antes y el de ahora. Es lo que el mostrador
--    ve para confirmar con el socio que fue él (`reviewedAt`), y con lo que se
--    cuenta el tope de cambios por periodo.
--  · La bitácora NO lleva los valores (es inmutable y sobreviviría a la
--    anonimización): lleva qué dato cambió y la terminación del celular. Los
--    valores viven aquí y se vacían cuando la ficha se anonimiza.

-- CreateTable
CREATE TABLE "member_contact_changes" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "batchId" UUID NOT NULL,
    "field" TEXT NOT NULL,
    "oldValue" TEXT,
    "newValue" TEXT,
    "sharedPhone" BOOLEAN NOT NULL DEFAULT false,
    "responsibleKind" TEXT,
    "sessionId" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewedAt" TIMESTAMPTZ(3),
    "reviewedByUserId" UUID,
    "forgottenAt" TIMESTAMPTZ(3),

    CONSTRAINT "member_contact_changes_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "member_contact_changes_field_chk" CHECK ("field" IN ('PHONE', 'EMAIL', 'EMERGENCY_NAME', 'EMERGENCY_PHONE'))
);

-- CreateIndex
CREATE INDEX "member_contact_changes_org_member_idx" ON "member_contact_changes"("organizationId", "memberId", "createdAt");
CREATE INDEX "member_contact_changes_org_pending_idx" ON "member_contact_changes"("organizationId", "reviewedAt");

-- AddForeignKey
ALTER TABLE "member_contact_changes" ADD CONSTRAINT "member_contact_changes_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "member_contact_changes" ADD CONSTRAINT "member_contact_changes_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE CASCADE ON UPDATE CASCADE;

-- La aplicación la lee, agrega, marca como confirmada y le vacía los valores al anonimizar.
GRANT SELECT, INSERT, UPDATE, DELETE ON "member_contact_changes" TO gymflow_app;
