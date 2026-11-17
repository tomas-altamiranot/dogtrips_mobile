# DogTrips Mobile

App Android para contratar paseadores de perros. El dueño abre un mapa, ve qué paseadores
hay cerca, revisa sus perfiles y reserva un paseo para su mascota.

**Programación de Dispositivos Móviles — Universidad Anáhuac Mayab**
Proyecto individual · Flutter · SQLite · OpenStreetMap

> DogTrips nació en 5.º semestre como una lista de requerimientos para Ingeniería de
> Software, y en 6.º se construyó como aplicación web. Esta es su versión móvil, y la
> primera que resuelve lo que el documento original pedía desde el principio: *"permitir a
> los dueños de mascotas buscar paseadores"*.

---

## Estado

| Componente | Estado |
|---|---|
| Modelo de datos y capa SQLite | 🚧 En curso |
| Mapa de paseadores cercanos | 🚧 Pendiente |
| Perfil del paseador y reserva | 🚧 Pendiente |
| Registro de mascotas con cámara | 🚧 Pendiente |
| Dictado por voz y login biométrico | 🚧 Trabajo futuro |

---

## 1. El problema

Contratar a alguien para que pasee a tu perro es un acto de confianza, y hoy se resuelve
por recomendación de boca en boca o por grupos de vecinos. No hay forma de saber quién
trabaja cerca de ti, qué experiencia tiene, ni cuánto cobra.

La app responde tres preguntas desde el lado del dueño:

1. **¿Quién pasea perros cerca de mí?**
2. **¿Puedo confiar en esta persona?**
3. **¿Cuánto me va a costar?**

### Qué deja fuera

Es deliberadamente la mitad del producto: **solo el lado del dueño**. La app del paseador
—aceptar solicitudes, registrar el paseo en curso— es la otra mitad del marketplace y no
entra en este alcance.

---

## 2. Arquitectura

```
┌──────────────────────────────────────────────┐
│  pantallas/     Scaffold · Drawer · rutas    │
│                 No contienen SQL             │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│  datos/         BaseDatos: la única clase    │
│                 que habla con SQLite         │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│  modelos/       Paseador · Mascota · Reserva │
│                 Saben serializarse, nada más │
└──────────────────────────────────────────────┘
```

Las dependencias apuntan en una sola dirección: **una pantalla puede pedir datos, pero una
clase de datos nunca sabe que existe una pantalla.** Si mañana la interfaz cambiara por
completo, `datos/` y `modelos/` seguirían intactos.

### Por qué SQLite y no una API

La app guarda todo en el teléfono. No es una limitación: es la decisión correcta para este
problema.

El documento de requerimientos original ya lo anticipaba — un paseo ocurre en la calle, y en
muchas colonias la cobertura falla. Una app que necesita red para mostrarte tus propias
reservas es inútil justo cuando la abres a media calle.

Los paseadores se **siembran** en la base la primera vez que la app arranca. En un sistema
real vendrían de un servidor; aquí vienen de un seed local, de la misma forma que el
proyecto hermano siembra su base de datos de grafos.

---

## 3. Modelo de datos

```
Mascota                        Paseador  (sembrado)        Reserva
  id                             id                          id
  nombre                         nombre                      mascotaId   ──┐
  raza                           zona                        paseadorId  ──┤
  tamano                         latitud, longitud           fechaHora     │
  edadMeses                      calificacion                duracionMin   │
  fotoPath                       tarifaHora                  instrucciones │
  notas                          experienciaMeses            estado        │
                                 verificado                  costoEstimado │
                                 habilidades                               │
       ▲                               ▲                                   │
       └───────────────────────────────┴───────────────────────────────────┘
```

### La tarifa

El cálculo viene del documento de requerimientos original:

> *"Se les calculará una tarifa basada en la duración del paseo, la distancia recorrida, el
> número de mascotas paseadas, peso y complexión de la mascota."*

Implementado en esta versión:

```
costo = tarifaHora × (duracionMin / 60) × factorTamano

factorTamano:  pequeño 1.00 · mediano 1.15 · grande 1.30
```

Distancia recorrida y número de mascotas quedan documentados como trabajo futuro: ambos
requieren datos que solo existen una vez el paseo ocurrió.

---

## 4. Decisiones técnicas

**`flutter_map` sobre OpenStreetMap, no Google Maps.** Incrustar Google Maps exige una API
key con tarjeta de crédito registrada. Para mostrar pines en un mapa, OSM hace lo mismo sin
esa barrera.

**El `Future` de cada pantalla vive en el `State`, no en `build()`.** `build()` se ejecuta en
cada repintado; crear ahí la consulta lanzaría una lectura nueva a la base cada vez y la
pantalla parpadearía sin parar.

**Las rutas se declaran como constantes.** Un nombre de ruta mal escrito dentro de un
`pushNamed` falla en tiempo de ejecución, y solo cuando alguien toca ese botón. Como
constante, lo atrapa el compilador.

**Los permisos se manejan en sus tres estados.** No basta con pedir el permiso: hay que
distinguir entre denegado una vez (se puede volver a pedir), denegado para siempre (hay que
mandar al usuario a los ajustes) y servicio apagado (el GPS del teléfono). Esa distinción es
la diferencia entre una app que explica qué pasa y una que se queda cargando para siempre.

---

## 5. Puesta en marcha

**Requisitos:** Flutter 3.50 o superior · Android SDK con las licencias aceptadas · un
emulador o dispositivo Android.

```bash
git clone https://github.com/tomas-altamiranot/dogtrips_mobile.git
cd dogtrips_mobile
flutter pub get
flutter run
```

Verificar que el entorno esté completo:

```bash
flutter doctor
```

Hace falta `[√] Android toolchain`. El aviso de Visual Studio puede ignorarse: corresponde a
compilar para escritorio Windows, que este proyecto no usa.

### Probar la ubicación en el emulador

El GPS del emulador no tiene señal real. En la barra lateral: `⋯` → **Location** → escribir
unas coordenadas y **Set Location**. Para Mérida: `20.9671`, `-89.6237`.

O desde la terminal (ojo: primero longitud, luego latitud):

```bash
adb emu geo fix -89.6237 20.9671
```

---

## 6. Pruebas

```bash
flutter test
```

Las pruebas cubren la serialización de los modelos, que es donde un error pasa inadvertido:
si convertir a mapa y volver deja de ser reversible, la app sigue compilando y los datos se
corrompen al guardarse.

---

## Autor

**Tomás Altamirano**
Ingeniería · Universidad Anáhuac Mayab

DogTrips es un proyecto propio, iniciado junto a Isaac Padilla y Stephanie Bayona como
ejercicio de ingeniería de requerimientos.
