-- PASE DE PRUEBA: SOLO SE AGREGA (auditoría 8, fase 3, bloque 3.3; D-08).
-- Segura con datos reales: solo recorta permisos del rol de la aplicación.
--
-- «Uno por persona» deja de ser cierto si un pase ya dado se puede borrar o
-- cambiar de celular desde la aplicación: bastaría borrarlo para estrenar
-- otro. La aplicación lo da y lo lee; no lo corrige ni lo borra. La tabla no
-- guarda el celular (solo su huella y cuatro dígitos), así que tampoco hay
-- aquí un dato personal que la anonimización tenga que tocar.
REVOKE UPDATE, DELETE ON "trial_passes" FROM gymflow_app;
