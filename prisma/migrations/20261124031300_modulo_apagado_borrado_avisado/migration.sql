-- Auditoría 8, fase 3, bloque 3.12 (D-32, paréntesis: «igual si se apaga
-- Biometría, con aviso»; pendiente desde la fase 0). Aditiva.
--
-- Apagar Biometría (en todo el gimnasio o en una sucursal) deja de reconocer
-- los rostros en el acto y los BORRA a los 30 días si no se vuelve a encender.
-- Solo cuando quien la apagó vio el aviso con el número de rostros y lo
-- confirmó: ese día se anota aquí la fecha del borrado y el número avisado.
--
--   erasureOn      el día en que se borra lo avisado; NULL = no hay nada
--                  avisado (así quedan TODAS las filas que ya existen: un
--                  módulo apagado antes de esta migración no borra nada);
--   erasureWarned  cuántos (rostros) decía el aviso.
--
-- Encender otra vez las deja en NULL: el borrado se cancela.
ALTER TABLE "organization_modules" ADD COLUMN "erasureOn" DATE, ADD COLUMN "erasureWarned" INTEGER;
ALTER TABLE "branch_module_overrides" ADD COLUMN "erasureOn" DATE, ADD COLUMN "erasureWarned" INTEGER;
