-- Reconocimiento facial con la cámara de recepción (2026-10-09), como las
-- estaciones de HRFlow. La plantilla (embedding de 512 números) vive CIFRADA
-- en el servidor del gimnasio, ligada a su enrolamiento y a su consentimiento.
-- Al revocar el enrolamiento se BORRA en el acto (no espera a ningún equipo).
CREATE TABLE "face_templates" (
  "enrollmentId" UUID NOT NULL,
  "organizationId" UUID NOT NULL,
  "branchId" UUID NOT NULL,
  "memberId" UUID NOT NULL,
  "embeddingEncrypted" TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "face_templates_pkey" PRIMARY KEY ("enrollmentId")
);
CREATE INDEX "face_templates_org_branch_idx" ON "face_templates"("organizationId", "branchId");
ALTER TABLE "face_templates" ADD CONSTRAINT "face_templates_enrollment_fk" FOREIGN KEY ("enrollmentId") REFERENCES "biometric_enrollments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "face_templates" ADD CONSTRAINT "face_templates_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
GRANT SELECT, INSERT, DELETE ON "face_templates" TO gymflow_app;
REVOKE UPDATE ON "face_templates" FROM gymflow_app;
