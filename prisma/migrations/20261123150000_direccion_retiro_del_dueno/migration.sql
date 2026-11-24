-- DIRECCIÓN (auditoría 8, fase 3, bloque 3.7; decisión D-23).
-- «Retiro del dueño»: lo que la dueña se lleva del negocio. Se anota junto a
-- los gastos (mismo mes, sucursal, anulación con motivo y bitácora) pero no
-- es un gasto: la analítica no lo resta de la ganancia. Solo se amplía la
-- lista de categorías; las filas que ya existen no cambian.
ALTER TABLE "operating_expenses" DROP CONSTRAINT "operating_expenses_category_chk";
ALTER TABLE "operating_expenses" ADD CONSTRAINT "operating_expenses_category_chk"
  CHECK ("category" IN ('RENT','PAYROLL','UTILITIES','SERVICES','MAINTENANCE','MARKETING','TAXES','OTHER','OWNER_DRAW'));
