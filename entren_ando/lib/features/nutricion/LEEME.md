# features/nutricion (pestaña Comidas)

Dueño: Ángel. Historias: ENT-45 (registro manual) y ENT-65 (escaneo con IA y límite de 3 por día).

## Qué hay aquí (ENT-45)

| Archivo | Qué hace |
| --- | --- |
| `comidas_repositorio.dart` | `ComidasRepositorio`: comidas del día y totales con `SUM` (calorías y macros) por fecha de Ciudad de México; `agregar`, `editar` y `borrar` (marca `eliminado = 1`) con `EscrituraLocal`. `ValidarComida` con las reglas de captura. `comidasDeHoyProvider` para la pantalla. |
| `pantalla_comidas.dart` | Pestaña Comidas como en `docs/pantallas/06_comidas.png` y `10_comidas_sin_red.png`: total del día, barra de macros, botones y lista. Tocar una comida la edita. |
| `hoja_comida.dart` | Hoja "Registrar comida" / "Editar comida": descripción, calorías y macros opcionales; borrar pide un segundo toque. |

Reglas:

* Calorías enteras y de 0 en adelante. Las macros son opcionales (gramos, con punto o coma).
* No hay meta calórica: no está en la ERS.
* Todo funciona en modo avión. Se guarda con `pendiente_sync = 1` y ENT-44 lo sube a Supabase.
* Después de guardar algo en comidas desde otro módulo: `ref.invalidate(comidasDeHoyProvider)`.

## Para ENT-65 (escaneo con IA)

* El botón "Escanear con cámara" ya está con `BotonConRed` y `alPresionar: null`; ENT-65 le pone
  la acción y el texto "Escaneos con IA hoy: 1 de 3 · plan Gratuito" debajo.
* Los escaneos del día se cuentan en `solicitud_ia` con `tipo = 'escaneo'`. El usuario demo ya trae
  1 escaneo hoy. Las comidas escaneadas se guardan con `origen = 'ia'` y `id_solicitud`.
