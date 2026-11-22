import 'dotenv/config';
import pg from 'pg';

const c = new pg.Client({ connectionString: process.env.DATABASE_URL_MIGRATOR });
await c.connect();

const show = async (title, sql, params = []) => {
  const { rows } = await c.query(sql, params);
  console.log(`\n── ${title} (${rows.length}) ──`);
  for (const r of rows) console.log('  ' + Object.values(r).join('  |  '));
};

await show('Tablas', `select tablename from pg_tables where schemaname='public' order by 1`);
await show('Índices parciales (WHERE)', `
  select indexname from pg_indexes
  where schemaname='public' and indexdef ilike '%WHERE%' order by 1`);
await show('FKs compuestas que cruzan tenant', `
  select conname from pg_constraint
  where contype='f' and cardinality(conkey) > 1 order by 1`);
await show('CHECK constraints propios', `
  select conname from pg_constraint
  where contype='c' and conname not like '%_not_null' and conrelid::regclass::text in
    (select tablename from pg_tables where schemaname='public') order by 1`);
await show('Triggers append-only', `
  select tgname || ' on ' || tgrelid::regclass from pg_trigger
  where not tgisinternal order by 1`);
await show('Privilegios de gymflow_app sobre audit_logs', `
  select privilege_type from information_schema.table_privileges
  where grantee='gymflow_app' and table_name='audit_logs' order by 1`);
await show('Extensiones', `select extname from pg_extension where extname in ('pg_trgm','btree_gist','pgcrypto') order by 1`);

await c.end();
