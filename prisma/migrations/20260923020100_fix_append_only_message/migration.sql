-- El mensaje anterior usaba `%s`: en plpgsql el marcador es `%`, así que la
-- `s` quedaba pegada al verbo ("DELETEs no está permitido"). Es cosmético,
-- pero este texto termina copiado en tickets de soporte.
CREATE OR REPLACE FUNCTION reject_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION '% es append-only: la operación % no está permitida',
    TG_TABLE_NAME, TG_OP;
END;
$$ LANGUAGE plpgsql;
