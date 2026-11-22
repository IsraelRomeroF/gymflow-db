-- El código de socio se forma con las TRES primeras letras del código de
-- sucursal (`CEN-00001`), y el contador de secuencia es POR SUCURSAL. Si dos
-- sedes comparten esas tres letras —"Polanco" y "Polanco Norte" dan ambas
-- `POL`— las dos emiten `POL-00001` y chocan contra
-- `members_org_code_active_key` de forma permanente: el reintento del
-- repositorio va empujando el contador sin converger.
--
-- El truncado se conserva porque recepción dicta estos códigos por teléfono y
-- un prefijo largo es peor. Lo que se garantiza es que el prefijo sea ÚNICO.
--
-- Si esta migración FALLA al aplicarse, es porque ya existen sedes con
-- prefijo repetido: hay que renombrar su código antes de continuar. Fallar
-- aquí es correcto; la alternativa es emitir códigos duplicados en silencio.
CREATE UNIQUE INDEX "branches_member_code_prefix_key"
  ON "branches" ("organizationId", (upper(left("code", 3))))
  WHERE "deletedAt" IS NULL;
