-- CreateEnum
CREATE TYPE "MuscleGroup" AS ENUM ('CHEST', 'BACK', 'SHOULDERS', 'BICEPS', 'TRICEPS', 'LEGS', 'GLUTES', 'ABS');

-- CreateTable
CREATE TABLE "exercises" (
    "id" UUID NOT NULL,
    "organizationId" UUID,
    "code" TEXT,
    "name" TEXT NOT NULL,
    "muscleGroup" "MuscleGroup" NOT NULL,
    "equipment" TEXT,
    "instructions" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exercises_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workout_templates" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "goal" TEXT,
    "level" TEXT,
    "notes" TEXT,
    "dayNames" TEXT[],
    "createdByUserId" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "archivedAt" TIMESTAMPTZ(3),

    CONSTRAINT "workout_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workout_template_items" (
    "id" UUID NOT NULL,
    "workoutTemplateId" UUID NOT NULL,
    "exerciseId" UUID NOT NULL,
    "dayIndex" INTEGER NOT NULL,
    "orderIndex" INTEGER NOT NULL,
    "sets" INTEGER NOT NULL,
    "reps" TEXT NOT NULL,
    "restSeconds" INTEGER,
    "notes" TEXT,

    CONSTRAINT "workout_template_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workout_assignments" (
    "id" UUID NOT NULL,
    "organizationId" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "workoutTemplateId" UUID NOT NULL,
    "assignedByUserId" UUID NOT NULL,
    "notes" TEXT,
    "assignedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMPTZ(3),

    CONSTRAINT "workout_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "exercises_code_key" ON "exercises"("code");

-- CreateIndex
CREATE INDEX "exercises_organizationId_muscleGroup_idx" ON "exercises"("organizationId", "muscleGroup");

-- CreateIndex
CREATE INDEX "workout_templates_organizationId_archivedAt_idx" ON "workout_templates"("organizationId", "archivedAt");

-- CreateIndex
CREATE UNIQUE INDEX "workout_templates_id_org_key" ON "workout_templates"("id", "organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "workout_template_items_workoutTemplateId_dayIndex_orderInde_key" ON "workout_template_items"("workoutTemplateId", "dayIndex", "orderIndex");

-- CreateIndex
CREATE INDEX "workout_assignments_organizationId_memberId_endedAt_idx" ON "workout_assignments"("organizationId", "memberId", "endedAt");

-- AddForeignKey
ALTER TABLE "exercises" ADD CONSTRAINT "exercises_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_templates" ADD CONSTRAINT "workout_templates_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_template_items" ADD CONSTRAINT "workout_template_items_workoutTemplateId_fkey" FOREIGN KEY ("workoutTemplateId") REFERENCES "workout_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_template_items" ADD CONSTRAINT "workout_template_items_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "exercises"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_assignments" ADD CONSTRAINT "workout_assignments_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_assignments" ADD CONSTRAINT "workout_assignments_member_same_org_fk" FOREIGN KEY ("memberId", "organizationId") REFERENCES "members"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_assignments" ADD CONSTRAINT "workout_assignments_template_same_org_fk" FOREIGN KEY ("workoutTemplateId", "organizationId") REFERENCES "workout_templates"("id", "organizationId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Una sola rutina ACTIVA por socio: asignar otra cierra la anterior.
CREATE UNIQUE INDEX "workout_assignments_one_active_per_member"
  ON "workout_assignments" ("memberId") WHERE "endedAt" IS NULL;
-- Un ejercicio del gimnasio no se hace pasar por uno del catálogo global.
ALTER TABLE "exercises" ADD CONSTRAINT "exercises_code_only_global_chk"
  CHECK ("code" IS NULL OR "organizationId" IS NULL);
ALTER TABLE "workout_template_items" ADD CONSTRAINT "workout_items_ranges_chk"
  CHECK ("dayIndex" BETWEEN 1 AND 7 AND "orderIndex" >= 1 AND "sets" BETWEEN 1 AND 20
         AND ("restSeconds" IS NULL OR "restSeconds" BETWEEN 0 AND 900));
