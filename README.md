# @gymflow/db

Esquema, migraciones y cliente de datos de GymFlow.

## Por qué es un repositorio aparte

El esquema es la frontera más dura del sistema: **las garantías de dinero
viven aquí**, no en la aplicación. Índices únicos parciales, `CHECK` de
aritmética y triggers *append-only* siguen valiendo aunque alguien se salte el
código.

## Reparto entre Prisma y SQL crudo

Aprendido a base de romperlo (ver `docs/sprints/02` y `03`):

| Va en `schema.prisma` | Va en SQL crudo de la migración |
|---|---|
| Únicos compuestos, relaciones compuestas | Índices **parciales** (`WHERE …`) |
| Índices normales **y GIN** | `CHECK` |
| Enums, modelos | Triggers, `GRANT`/`REVOKE`, `CREATE EXTENSION` |

Poner en SQL crudo algo que Prisma sabe representar hace que lo trate como
deriva y lo **borre** en la siguiente migración.

## Dos trampas que ya nos costaron

- **`GRANT … ON ALL TABLES` deshace los `REVOKE` anteriores.** Toda migración
  que haga un `GRANT` masivo debe reaplicar *todos* los `REVOKE`, incluidos los
  de sprints previos.
- **El nombre de la carpeta de migración es su orden de aplicación.** Un
  entorno nuevo las aplica en orden alfabético, no en el que las creaste. Si el
  timestamp queda fuera de orden, el historial no es reproducible y el primer
  despliegue falla.

## Uso

```bash
pnpm install
pnpm bootstrap        # crea gymflow_dev, gymflow_shadow, roles y extensiones
pnpm migrate:deploy
pnpm seed             # catálogo de permisos y roles
pnpm seed:demo        # 2 organizaciones, 4 sucursales, 5 usuarios, planes, cajas
pnpm build            # genera el cliente y emite dist/
pnpm verify:schema    # imprime índices parciales, CHECKs, triggers y privilegios
```

`DATABASE_URL` apunta al rol **no propietario** (`gymflow_app`);
`DATABASE_URL_MIGRATOR` al propietario. Esa separación es lo que hace efectivos
los `REVOKE` (ADR-001).
