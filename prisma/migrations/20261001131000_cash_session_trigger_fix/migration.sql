-- Corrección del trigger anterior: PL/pgSQL no corta el AND, así que leía
-- NEW."status" también en pagos (otro enum) y en movimientos (no existe).
CREATE OR REPLACE FUNCTION gymflow_cash_session_must_be_open() RETURNS trigger AS $$
DECLARE
  sesion uuid;
  estado text;
BEGIN
  sesion := NEW."cashSessionId";
  IF sesion IS NULL THEN RETURN NEW; END IF;
  -- En una venta, solo importa al crearla o al anularla.
  IF TG_TABLE_NAME = 'pos_sales' THEN
    IF TG_OP = 'UPDATE' THEN
      IF NOT (NEW."status"::text = 'VOIDED' AND OLD."status"::text <> 'VOIDED') THEN
        RETURN NEW;
      END IF;
    END IF;
  END IF;
  SELECT "status"::text INTO estado FROM "cash_sessions" WHERE "id" = sesion FOR SHARE;
  IF estado IS DISTINCT FROM 'OPEN' THEN
    RAISE EXCEPTION 'El turno de caja % ya no está abierto', sesion USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
