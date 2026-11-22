/**
 * Catálogo GLOBAL de ejercicios: diez por bloque muscular.
 *
 * Es el punto de partida del coach, no un límite: cada gimnasio agrega los
 * suyos. La `code` es estable para que sembrar dos veces no duplique; la
 * instrucción es una sola frase de técnica, lo que cabe en el celular del
 * socio entre serie y serie.
 */
export type EjercicioBase = {
  code: string; name: string;
  muscleGroup: 'CHEST' | 'BACK' | 'SHOULDERS' | 'BICEPS' | 'TRICEPS' | 'LEGS' | 'GLUTES' | 'ABS';
  equipment: string; instructions: string;
};

const bloque = (
  prefijo: string, muscleGroup: EjercicioBase['muscleGroup'],
  items: Array<[name: string, equipment: string, instructions: string]>,
): EjercicioBase[] => items.map(([name, equipment, instructions], i) => ({
  code: `${prefijo}-${String(i + 1).padStart(2, '0')}`, name, muscleGroup, equipment, instructions,
}));

export const EJERCICIOS: readonly EjercicioBase[] = [
  ...bloque('PECHO', 'CHEST', [
    ['Press de banca con barra', 'Barra', 'Baja la barra al pecho con los codos a 45° y empuja sin despegar la espalda.'],
    ['Press de banca con mancuernas', 'Mancuernas', 'Baja hasta sentir el estiramiento del pecho y sube juntando las mancuernas.'],
    ['Press inclinado con barra', 'Barra', 'Banco a 30°; baja a la parte alta del pecho.'],
    ['Press inclinado con mancuernas', 'Mancuernas', 'Banco a 30°; controla la bajada en dos segundos.'],
    ['Press declinado', 'Barra', 'Pies asegurados; baja a la parte baja del pecho.'],
    ['Aperturas con mancuernas', 'Mancuernas', 'Codos ligeramente flexionados; abre sin pasar la línea del hombro.'],
    ['Cruce de poleas', 'Polea', 'Da un paso al frente y junta las manos a la altura del ombligo.'],
    ['Fondos en paralelas (pecho)', 'Paralelas', 'Inclina el torso al frente y baja hasta 90° de codo.'],
    ['Lagartijas', 'Peso corporal', 'Cuerpo recto de cabeza a talones; pecho casi al piso.'],
    ['Pec deck', 'Máquina', 'Espalda pegada al respaldo; junta sin chocar las manos.'],
  ]),
  ...bloque('ESPALDA', 'BACK', [
    ['Dominadas', 'Barra fija', 'Agarre prono; sube hasta pasar la barbilla y baja completo.'],
    ['Jalón al pecho', 'Polea', 'Lleva la barra a la parte alta del pecho sacando el pecho.'],
    ['Remo con barra', 'Barra', 'Torso a 45°, espalda neutra; jala hacia el ombligo.'],
    ['Remo con mancuerna a una mano', 'Mancuerna', 'Apoya rodilla y mano en el banco; jala el codo hacia la cadera.'],
    ['Remo sentado en polea', 'Polea', 'Pecho alto; junta los omóplatos al final de cada jalón.'],
    ['Remo en máquina', 'Máquina', 'Pecho contra el apoyo; jala sin encoger los hombros.'],
    ['Peso muerto convencional', 'Barra', 'Barra pegada a las piernas, espalda neutra; empuja el piso.'],
    ['Pullover en polea', 'Polea', 'Brazos casi rectos; baja la barra hasta los muslos.'],
    ['Remo T', 'Barra T', 'Pecho al frente; jala hacia el abdomen sin rebotar.'],
    ['Hiperextensiones', 'Banco romano', 'Baja con la espalda neutra y sube hasta alinear el cuerpo.'],
  ]),
  ...bloque('HOMBRO', 'SHOULDERS', [
    ['Press militar con barra', 'Barra', 'De pie, glúteos apretados; empuja la barra sobre la cabeza.'],
    ['Press de hombro con mancuernas', 'Mancuernas', 'Sentado; baja hasta la altura de las orejas.'],
    ['Press Arnold', 'Mancuernas', 'Gira las palmas mientras empujas hacia arriba.'],
    ['Elevaciones laterales', 'Mancuernas', 'Sube hasta la altura del hombro con el codo ligeramente flexionado.'],
    ['Elevaciones frontales', 'Mancuernas', 'Sube al frente hasta la altura de los ojos sin balancearte.'],
    ['Pájaros (deltoide posterior)', 'Mancuernas', 'Torso inclinado; abre los brazos llevando los codos atrás.'],
    ['Face pull', 'Polea', 'Cuerda a la altura de la cara; jala separando las manos.'],
    ['Remo al mentón', 'Barra', 'Agarre amplio; sube los codos hasta la altura del hombro.'],
    ['Elevación lateral en polea', 'Polea', 'Un brazo a la vez; controla la bajada.'],
    ['Press de hombro en máquina', 'Máquina', 'Ajusta el asiento para que las manijas queden a la altura del hombro.'],
  ]),
  ...bloque('BICEPS', 'BICEPS', [
    ['Curl con barra', 'Barra', 'Codos pegados al cuerpo; sube sin balancear el torso.'],
    ['Curl con mancuernas alterno', 'Mancuernas', 'Gira la palma hacia arriba al subir.'],
    ['Curl martillo', 'Mancuernas', 'Palmas enfrentadas durante todo el movimiento.'],
    ['Curl concentrado', 'Mancuerna', 'Codo apoyado en el muslo; aprieta arriba un segundo.'],
    ['Curl en banco Scott', 'Barra Z', 'Brazos apoyados; no extiendas del todo al bajar.'],
    ['Curl en polea baja', 'Polea', 'Tensión constante; codos fijos.'],
    ['Curl con barra Z', 'Barra Z', 'Agarre en la parte angulada para cuidar las muñecas.'],
    ['Curl inclinado con mancuernas', 'Mancuernas', 'Banco a 45°; deja colgar los brazos antes de subir.'],
    ['Curl araña', 'Mancuernas', 'Pecho apoyado en banco inclinado; brazos verticales.'],
    ['Curl 21', 'Barra', 'Siete medias repeticiones abajo, siete arriba y siete completas.'],
  ]),
  ...bloque('TRICEPS', 'TRICEPS', [
    ['Press francés', 'Barra Z', 'Acostado; baja la barra hacia la frente moviendo solo el codo.'],
    ['Extensión en polea con cuerda', 'Polea', 'Codos pegados; separa la cuerda al final.'],
    ['Extensión en polea con barra', 'Polea', 'Empuja hacia abajo hasta extender por completo.'],
    ['Fondos en banco', 'Banco', 'Manos en el banco detrás de ti; baja hasta 90° de codo.'],
    ['Press cerrado', 'Barra', 'Manos al ancho de los hombros; codos pegados al bajar.'],
    ['Extensión sobre la cabeza con mancuerna', 'Mancuerna', 'Sostén con ambas manos; baja detrás de la cabeza.'],
    ['Patada de tríceps', 'Mancuerna', 'Torso inclinado; extiende el brazo atrás sin mover el codo.'],
    ['Fondos en paralelas (tríceps)', 'Paralelas', 'Torso vertical; baja controlado.'],
    ['Extensión a una mano en polea', 'Polea', 'Agarre invertido; un brazo a la vez.'],
    ['Lagartijas diamante', 'Peso corporal', 'Manos juntas formando un diamante bajo el pecho.'],
  ]),
  ...bloque('PIERNA', 'LEGS', [
    ['Sentadilla con barra', 'Barra', 'Barra en la espalda alta; baja con las rodillas en línea con los pies.'],
    ['Prensa de piernas', 'Máquina', 'Pies al ancho de cadera; no bloquees las rodillas arriba.'],
    ['Sentadilla goblet', 'Mancuerna', 'Mancuerna pegada al pecho; torso erguido.'],
    ['Zancadas caminando', 'Mancuernas', 'Paso largo; la rodilla de atrás casi toca el piso.'],
    ['Sentadilla búlgara', 'Mancuernas', 'Pie trasero en el banco; baja con el torso vertical.'],
    ['Extensión de cuádriceps', 'Máquina', 'Sube hasta extender y aprieta un segundo.'],
    ['Curl femoral acostado', 'Máquina', 'Cadera pegada al banco; lleva los talones al glúteo.'],
    ['Peso muerto rumano', 'Barra', 'Rodillas semiflexionadas; baja la barra pegada a las piernas.'],
    ['Elevación de talones de pie', 'Máquina', 'Sube en puntas y baja hasta estirar la pantorrilla.'],
    ['Sentadilla hack', 'Máquina', 'Espalda pegada al respaldo; baja hasta 90° de rodilla.'],
  ]),
  ...bloque('GLUTEO', 'GLUTES', [
    ['Hip thrust con barra', 'Barra', 'Espalda alta en el banco; sube la cadera y aprieta arriba.'],
    ['Puente de glúteo', 'Peso corporal', 'Acostado; empuja con los talones y sube la cadera.'],
    ['Patada de glúteo en polea', 'Polea', 'Tobillera en la polea; lleva la pierna atrás sin arquear la espalda.'],
    ['Abducción en máquina', 'Máquina', 'Abre las piernas controlando el regreso.'],
    ['Peso muerto sumo', 'Barra', 'Postura amplia, puntas afuera; empuja con los glúteos.'],
    ['Step-up al cajón', 'Mancuernas', 'Sube empujando con el talón de la pierna que está arriba.'],
    ['Sentadilla sumo con mancuerna', 'Mancuerna', 'Postura amplia; baja con el torso erguido.'],
    ['Patada de burro', 'Peso corporal', 'En cuatro puntos; sube el talón hacia el techo.'],
    ['Caminata lateral con liga', 'Liga', 'Semisentadilla; pasos laterales sin juntar los pies.'],
    ['Buenos días', 'Barra', 'Barra en la espalda; inclina el torso con la espalda neutra.'],
  ]),
  ...bloque('ABDOMEN', 'ABS', [
    ['Plancha', 'Peso corporal', 'Antebrazos y puntas; cuerpo recto sin hundir la cadera.'],
    ['Crunch', 'Peso corporal', 'Sube los hombros del piso sin jalar el cuello.'],
    ['Elevación de piernas colgado', 'Barra fija', 'Sube las piernas sin balancearte.'],
    ['Crunch en polea', 'Polea', 'De rodillas; flexiona el torso llevando los codos a los muslos.'],
    ['Plancha lateral', 'Peso corporal', 'Apoyo en un antebrazo; cadera alineada.'],
    ['Rueda abdominal', 'Rueda', 'Desde rodillas; avanza sin arquear la zona lumbar.'],
    ['Giro ruso', 'Disco', 'Sentado con el torso inclinado; gira de lado a lado.'],
    ['Bicicleta', 'Peso corporal', 'Codo al lado contrario de la rodilla, alternando.'],
    ['Dead bug', 'Peso corporal', 'Boca arriba; extiende brazo y pierna contrarios sin despegar la espalda.'],
    ['Escaladores', 'Peso corporal', 'Posición de lagartija; lleva las rodillas al pecho alternando rápido.'],
  ]),
];
