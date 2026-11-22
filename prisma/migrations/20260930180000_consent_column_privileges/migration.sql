-- SEC-15: la evidencia de consentimiento solo se puede REVOCAR.
--
-- El trigger `member_consents_immutable` ya protege versión, texto, fecha y
-- hash, pero la aplicación aún podía reescribir IP, navegador, canal o a
-- quién pertenece: lo que se usa para demostrar que el titular aceptó. Con
-- privilegios por columna, el rol de la aplicación solo puede escribir la
-- revocación. Es una segunda barrera: aunque el código cambie, la base no.
--
-- ATENCIÓN: un `GRANT ... ON ALL TABLES` posterior deshace esto. Si alguna
-- migración lo vuelve a necesitar, debe repetir estas dos líneas después.
REVOKE UPDATE ON "member_consents" FROM gymflow_app;
GRANT UPDATE ("revokedAt") ON "member_consents" TO gymflow_app;
