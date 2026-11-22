import { cp, rm } from 'node:fs/promises';
import { resolve } from 'node:path';

/**
 * Copia el cliente generado de Prisma a `dist/`.
 *
 * `tsc` no lo compila —está excluido a propósito, son miles de líneas
 * generadas— pero `dist/index.js` lo importa con una ruta relativa. Sin esta
 * copia el paquete compila bien y REVIENTA al importarlo, que es la peor
 * combinación posible: el fallo aparece en despliegue, no en CI.
 */
const raiz = resolve(import.meta.dirname, '..');
const origen = resolve(raiz, 'src/generated');
const destino = resolve(raiz, 'dist/generated');

await rm(destino, { recursive: true, force: true });
await cp(origen, destino, { recursive: true });
console.log('cliente de Prisma copiado a dist/generated');
