-- BE2-12 / BE2-13: nada entra ni sale de un turno de caja que ya no está
-- abierto. Antes un cobro que había elegido el turno justo antes del corte se
-- insertaba DESPUÉS, en un turno cerrado cuyo esperado ya no lo incluía; y
-- anular una venta tras el corte la quitaba del turno ya firmado mientras el
-- efectivo salía del cajón de otro.
--
-- El trigger toma el turno con FOR SHARE: el cierre lo toma FOR UPDATE, así
-- que un cobro en curso termina antes de que se calcule el esperado, y uno
-- que llega después encuentra el turno cerrado y se rechaza.
CREATE OR REPLACE FUNCTION gymflow_cash_session_must_be_open() RETURNS trigger AS $$
DECLARE
  sesion uuid;
  estado text;
BEGIN
  sesion := NEW."cashSessionId";
  IF sesion IS NULL THEN RETURN NEW; END IF;
  -- En una venta, solo importa al crearla o al anularla.
  IF TG_TABLE_NAME = 'pos_sales' AND TG_OP = 'UPDATE'
     AND NOT (NEW."status" = 'VOIDED' AND OLD."status" <> 'VOIDED') THEN
    RETURN NEW;
  END IF;
  SELECT "status"::text INTO estado FROM "cash_sessions" WHERE "id" = sesion FOR SHARE;
  IF estado IS DISTINCT FROM 'OPEN' THEN
    RAISE EXCEPTION 'El turno de caja % ya no está abierto', sesion USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payments_cash_session_open BEFORE INSERT ON "payments"
  FOR EACH ROW EXECUTE FUNCTION gymflow_cash_session_must_be_open();
CREATE TRIGGER pos_sales_cash_session_open BEFORE INSERT OR UPDATE ON "pos_sales"
  FOR EACH ROW EXECUTE FUNCTION gymflow_cash_session_must_be_open();
CREATE TRIGGER cash_movements_session_open BEFORE INSERT ON "cash_movements"
  FOR EACH ROW EXECUTE FUNCTION gymflow_cash_session_must_be_open();
