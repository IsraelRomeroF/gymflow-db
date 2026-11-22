import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/client/client.js';

/**
 * Cliente de Prisma para el RUNTIME.
 *
 * Usa DATABASE_URL, que apunta al rol `gymflow_app`: NO es propietario de las
 * tablas. Eso es lo que hace efectivos el REVOKE DELETE sobre la bitácora y,
 * en la fase 2, el RLS con FORCE ROW LEVEL SECURITY (ADR-001).
 *
 * Las migraciones NUNCA pasan por aquí: usan `gymflow_owner` vía prisma.config.ts.
 */
export function createPrismaClient(connectionString = process.env.DATABASE_URL) {
  if (!connectionString) {
    throw new Error('Falta DATABASE_URL');
  }
  // Pool y tiempos límite explícitos (OPT2-03). Sin ellos regía el valor de
  // `pg`: 10 conexiones, espera infinita por una conexión y consultas sin
  // techo. Una ruta pesada agotaba el pool y el mostrador esperaba detrás.
  const numero = (v: string | undefined, def: number) => (v && /^\d+$/.test(v) ? Number(v) : def);
  const adapter = new PrismaPg({
    connectionString,
    max: numero(process.env.DB_POOL_MAX, 20),
    connectionTimeoutMillis: numero(process.env.DB_POOL_TIMEOUT_MS, 5_000),
    idleTimeoutMillis: 30_000,
    // Una consulta desbocada se corta; los jobs pueden subirlo con su propia variable.
    statement_timeout: numero(process.env.DB_STATEMENT_TIMEOUT_MS, 15_000),
    // Una petición bloqueada falla en 5 s en vez de colgar al mostrador 15 o
    // 20 (OPT3-06), y una transacción que se quedó abierta sin hacer nada
    // suelta sus candados en 30 s.
    lock_timeout: numero(process.env.DB_LOCK_TIMEOUT_MS, 5_000),
    idle_in_transaction_session_timeout: numero(process.env.DB_IDLE_TX_TIMEOUT_MS, 30_000),
    // La sesión SIEMPRE en UTC: el adaptador manda las fechas sin desfase, y
    // con la base en la zona de CDMX (o la que tenga el servidor) cada ventana
    // de tiempo se corría 6 horas. Las horas locales se piden con AT TIME ZONE.
    options: '-c TimeZone=UTC',
  });
  // DB_LOG_QUERIES=1 emite cada consulta como evento (`$on('query')`): es lo
  // que usan las mediciones de rendimiento para contar consultas por ruta.
  const consultas = process.env.DB_LOG_QUERIES ? [{ emit: 'event', level: 'query' } as const] : [];
  return new PrismaClient({
    adapter,
    log: [...consultas, ...(process.env.NODE_ENV === 'development' ? (['warn', 'error'] as const) : (['error'] as const))],
  });
}

export type Db = ReturnType<typeof createPrismaClient>;
