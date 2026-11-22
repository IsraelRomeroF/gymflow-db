-- Un cargo con pagos aplicados no se ANULA: se revierte el pago o se acredita.
-- Anularlo dejaba el dinero asignado a un cargo que "no existe", fuera del
-- saldo del socio y de la cartera. Pasaba al cancelar una clase ya pagada.
ALTER TABLE "charges" ADD CONSTRAINT "charges_void_without_payments_chk"
  CHECK ("status" <> 'VOID' OR "allocatedCents" = 0);
