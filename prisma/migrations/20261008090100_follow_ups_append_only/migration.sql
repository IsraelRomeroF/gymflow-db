-- El seguimiento es de solo agregar: los privilegios por omisión dan UPDATE y
-- DELETE a la aplicación en toda tabla nueva; aquí se retiran (ver la nota de
-- sprint2 sobre GRANT ... ON ALL TABLES y los REVOKE).
REVOKE UPDATE, DELETE ON "follow_ups" FROM gymflow_app;
