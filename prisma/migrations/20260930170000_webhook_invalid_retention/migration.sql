-- Retención (SEC-08 / SEC-05): los webhooks con firma INVÁLIDA solo sirven
-- unos días para investigar un intento de ataque, y cualquiera podía llenar
-- la tabla con ellos. La aplicación puede borrarlos; los VÁLIDOS siguen
-- siendo intocables: son la evidencia de lo que dijo el procesador.
GRANT DELETE ON "webhook_events" TO gymflow_app;

CREATE OR REPLACE FUNCTION webhook_events_solo_borrar_invalidos() RETURNS trigger AS $$
BEGIN
  IF OLD."signatureStatus" <> 'INVALID' THEN
    RAISE EXCEPTION 'Solo se borran webhooks con firma inválida (%)', OLD.id;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER webhook_events_solo_borrar_invalidos
  BEFORE DELETE ON "webhook_events"
  FOR EACH ROW EXECUTE FUNCTION webhook_events_solo_borrar_invalidos();
