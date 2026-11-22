/**
 * Crea la base de datos y los DOS roles del proyecto, sin tocar nada más
 * del clúster. Idempotente: se puede ejecutar varias veces.
 *
 *   gymflow_owner -> dueño de las tablas. SOLO para migraciones.
 *   gymflow_app   -> rol de la aplicación. NO es dueño de las tablas, que es
 *                    el requisito para poder activar RLS en la fase 2
 *                    (ADR-001) y para que REVOKE DELETE sea efectivo.
 */
import pg from 'pg';

const ADMIN = process.env.PGADMIN_URL ?? 'postgresql://postgres@localhost/postgres?host=/tmp';
const DB = process.env.GYMFLOW_DB ?? 'gymflow_dev';
const OWNER_PW = process.env.GYMFLOW_OWNER_PASSWORD ?? 'gymflow_owner_dev';
const APP_PW = process.env.GYMFLOW_APP_PASSWORD ?? 'gymflow_app_dev';

const q = (s) => s.replace(/'/g, "''");

async function main() {
  const admin = new pg.Client({ connectionString: ADMIN });
  await admin.connect();

  const { rows: existing } = await admin.query('select 1 from pg_database where datname = $1', [DB]);
  console.log(`base ${DB}: ${existing.length ? 'ya existe' : 'creando'}`);

  for (const [role, pw] of [['gymflow_owner', OWNER_PW], ['gymflow_app', APP_PW]]) {
    const { rows } = await admin.query('select 1 from pg_roles where rolname = $1', [role]);
    if (rows.length === 0) {
      await admin.query(`CREATE ROLE ${role} LOGIN PASSWORD '${q(pw)}'`);
      console.log(`rol ${role}: creado`);
    } else {
      await admin.query(`ALTER ROLE ${role} LOGIN PASSWORD '${q(pw)}'`);
      console.log(`rol ${role}: ya existía (contraseña actualizada)`);
    }
  }

  if (existing.length === 0) {
    await admin.query(`CREATE DATABASE ${DB} OWNER gymflow_owner`);
    console.log(`base ${DB}: creada`);
  }

  // Base shadow dedicada para Prisma Migrate. Se crea aquí en lugar de
  // conceder CREATEDB a gymflow_owner: este clúster lo comparten otros
  // proyectos y el rol no debe poder crear bases arbitrarias.
  const SHADOW = `${DB.replace(/_dev$/, '')}_shadow`;
  const { rows: sh } = await admin.query('select 1 from pg_database where datname = $1', [SHADOW]);
  if (sh.length === 0) {
    await admin.query(`CREATE DATABASE ${SHADOW} OWNER gymflow_owner`);
    console.log(`base ${SHADOW}: creada (shadow de Prisma Migrate)`);
  } else {
    console.log(`base ${SHADOW}: ya existe`);
  }
  await admin.end();

  // Extensiones y privilegios dentro de la base nueva.
  //
  // La conexión se DERIVA de PGADMIN_URL cambiándole la base. Antes llevaba
  // `?host=/tmp` fijo, así que el script solo funcionaba donde PostgreSQL
  // escucha en un socket Unix en esa ruta: en CI, en Docker o contra un
  // clúster remoto fallaba con `ENOENT /tmp/.s.PGSQL.5432`. Lo descubrió el
  // primer pipeline.
  const inDbUrl = new URL(ADMIN);
  inDbUrl.pathname = `/${DB}`;
  const inDb = new pg.Client({ connectionString: inDbUrl.toString() });
  await inDb.connect();
  for (const ext of ['pg_trgm', 'btree_gist', 'pgcrypto']) {
    await inDb.query(`CREATE EXTENSION IF NOT EXISTS ${ext}`);
  }
  await inDb.query('ALTER SCHEMA public OWNER TO gymflow_owner');
  await inDb.query('GRANT USAGE ON SCHEMA public TO gymflow_app');
  // gymflow_app NO puede crear objetos: solo usarlos.
  await inDb.query('REVOKE CREATE ON SCHEMA public FROM gymflow_app');
  const { rows: exts } = await inDb.query(
    "select extname from pg_extension where extname in ('pg_trgm','btree_gist','pgcrypto') order by 1",
  );
  console.log('extensiones:', exts.map((r) => r.extname).join(', '));
  await inDb.end();
  console.log('\nbootstrap completado.');
}

main().catch((err) => { console.error('ERROR:', err.message); process.exit(1); });
