-- La plataforma puede limitar lo que ve el DUEÑO (2026-10-09). El dueño está
-- exento de la llave que él mismo maneja para su personal; esta es otra: la
-- pone GymFlow. NULL = sin límite (ve todo, como siempre).
ALTER TABLE "users" ADD COLUMN "platformSections" JSONB;
