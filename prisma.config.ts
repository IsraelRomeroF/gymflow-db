import 'dotenv/config';
import { defineConfig } from 'prisma/config';

/**
 * Configuración de Prisma CLI (migraciones e introspección).
 *
 * Usa DELIBERADAMENTE el rol propietario: `gymflow_owner`.
 * El runtime de la aplicación NUNCA usa estas credenciales — entra con
 * `gymflow_app`, que no es dueño de las tablas (ADR-001).
 */
export default defineConfig({
  schema: 'prisma/schema.prisma',
  datasource: {
    url: process.env.DATABASE_URL_MIGRATOR!,
    shadowDatabaseUrl: process.env.SHADOW_DATABASE_URL!,
  },
  migrations: {
    seed: 'tsx src/seed.ts',
  },
});
