# Pruebas de cifrado y sincronización (ENT-55)

Sprint 3 · Responsable: Ángel Pedraza · Última corrida: 23 de noviembre de 2026

Prueban el código de ENT-44 (subir), ENT-53 (bajar, conflictos y regla de 30 días, PR #19) y las
políticas RLS de `supabase/politicas.sql`.

## Resumen

| # | Prueba | Cómo se probó | Resultado |
| --- | --- | --- | --- |
| 1 | El archivo `.db` no abre sin la llave en DB Browser for SQLite | Celular / emulador | ⏳ Falta la captura |
| 2 | Un cambio hecho sin red aparece en Supabase al volver la red | Simulador + emulador | ✅ Pasa en el simulador |
| 3 | En un conflicto gana el cambio más reciente | Simulador | ✅ Pasa |
| 4 | Un borrado (`eliminado = 1`) se sincroniza | Simulador | ✅ Pasa |
| 5 | Un usuario no ve los datos de otro (RLS) | Simulador | ✅ Pasa |
| 6 | El servidor rechaza cambios a sesiones de más de 30 días | Simulador | ✅ Pasa |

No se encontró ningún error, así que no se abrió ninguna incidencia de tipo Error.

## Cómo se probó

**Simulador** (`docs/pruebas/simulador/`): un PostgreSQL 16 local que imita Supabase con los mismos
archivos del repositorio (`supabase/esquema.sql`, `politicas.sql`, `ajustes_ent44.sql` y
`ajustes_ent53.sql`), los roles `anon` y `authenticated` y `auth.uid()`. El celular es una base SQLite
con `lib/core/db/esquema.sql` y los datos de prueba. Los scripts leen las listas de tablas de
`motor_sync.dart` y repiten lo que hace `MotorSync` (subir por lotes, bajar por `actualizado_en`, "gana
el más reciente" y el código `EA010`). Así se prueba el servidor real (RLS y trigger) sin tocar el
proyecto de Supabase del equipo.

```bash
# Linux o WSL con PostgreSQL 16, como root
cd docs/pruebas/simulador
bash nube_limpia.sh        # nube limpia
python3 pruebas55.py       # pruebas 2 a 6
```

Preparación: se suben las 500 filas del usuario demo (0 rechazadas).

**Celular o emulador:** las pruebas 1 y 2 también se hacen en la app (pasos abajo) y las capturas van
en `docs/pruebas/capturas/`.

---

## 1. Cifrado: el `.db` no abre sin la llave

La base local usa SQLCipher con una llave guardada en el Keystore (`flutter_secure_storage`). Sin esa
llave el archivo es ruido.

Pasos (app en modo debug en el emulador, en PowerShell desde la carpeta del proyecto):

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb shell "run-as mx.entrenando.app cat databases/entren_ando.db > /sdcard/Download/entren_ando.db"
& $adb pull /sdcard/Download/entren_ando.db
[System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes("$PWD\entren_ando.db")[0..15])
```

(No se usa `adb exec-out ... > archivo` porque PowerShell cambia los bytes al redirigir.)

1. Una base SQLite normal empieza con el texto `SQLite format 3`. La cifrada empieza con bytes al azar.
   Captura: `capturas/01_cabecera.png`.
2. Abrir `entren_ando.db` en **DB Browser for SQLite**: debe decir que el archivo no es una base de datos
   o pedir contraseña, y no muestra tablas. Captura: `capturas/01_db_browser.png`.

Resultado esperado: el archivo no abre y la cabecera no dice `SQLite format 3`.

> Captura pendiente: se toma en la computadora de Ángel con el emulador.

## 2. Un cambio hecho sin red aparece en la nube al volver la red

Simulador:

```text
Sin red: en el celular pendiente_sync = 1 | en la nube: 0 fila(s)
Vuelve la red → sincronizar: (1, 0, 0) (subidas, descartadas RF-10, rechazadas)
En la nube: Prueba ENT-55: avena · 350 kcal | en el celular pendiente_sync = 0
```

En el emulador (captura `capturas/02_*.png`):

1. Modo avión. En Comidas registrar "Prueba ENT-55: avena", 350 kcal.
2. Perfil → Respaldo en la nube muestra "1 cambio por subir" y el botón Sincronizar ahora desactivado.
3. Quitar el modo avión: la app sincroniza sola y muestra "Todo respaldado".
4. En Supabase → Table Editor → `registro_comida` aparece la fila.

## 3. En un conflicto gana el cambio más reciente

Se cambia la misma comida en la nube y en el celular con horas distintas.

```text
a) Celular más reciente (380) vs nube (400, hace 10 min) → celular = 380 → subir (1, 0, 0) → nube = 380
b) Nube más reciente (420) vs celular (390, viejo) → celular = (420, 0) (calorías, pendiente_sync)
```

En a) gana el celular y su versión sube. En b) gana la nube, el celular se queda con 420 y ya no tiene
nada pendiente.

## 4. Un borrado (`eliminado = 1`) se sincroniza

Se borra en el celular una sesión reciente con sus registros y series (como lo hace la app, en
cascada) y una comida.

```text
Borrar en el celular 1 sesión (con 5 registros y sus series) y 1 comida → subir: (24, 0, 0)
En la nube: sesión eliminado = t | registros eliminados = 5 de 5 | series eliminadas = 17 de 17 | comida eliminado = t | filas borradas con DELETE: 0 (siguen 1 fila)
Otro celular baja todo → la sesión borrada llega con eliminado = 1 (no aparece en pantallas que filtran eliminado = 0: 0 filas)
```

Nada se borra con `DELETE`: la fila sigue en la nube con `eliminado = true` y otro celular también la
recibe borrada.

## 5. Un usuario no ve los datos de otro (RLS)

Se crea un segundo usuario (`otro@entrenando.test`) y se consulta con su sesión.

```text
Demo ve sus sesiones: 31 | el otro usuario ve: 0 | comidas que ve el otro: 0 | series que ve el otro: 0
El otro intenta cambiar una comida del demo → filas cambiadas: 0 | calorías en la nube siguen en 420
El otro intenta guardar una comida a nombre del demo → ERROR: new row violates row-level security policy for table "registro_comida"
Sin sesión (anon), consultar sesiones → sin permiso
```

## 6. El servidor rechaza cambios a sesiones de más de 30 días (RF-10)

```text
Sesión del 2026-10-09 — el demo intenta cambiarla directo en la nube → ERROR: RF-10: no se puede cambiar el 2026-10-09 porque tiene más de 30 días
Código del error: EA010 capturado
Desde el celular → subir (subidas, descartadas RF-10, rechazadas): (0, 1, 0) | comentario en la nube: '' | en el celular: (None, 0)
Control: sesión de hace menos de 30 días sí se cambia → 1 fila cambiada
```

El trigger de `ajustes_ent53.sql` rechaza el cambio con el código `EA010`. El celular lo reconoce, se
queda con la versión de la nube y ya no lo intenta otra vez. Una sesión reciente sí se puede cambiar.

## Pendiente

* Capturas de la prueba 1 y de la prueba 2 en el emulador (en `docs/pruebas/capturas/`).
* Correr `supabase/ajustes_ent53.sql` en el proyecto de Supabase del equipo (parte de PR #19) y repetir
  la prueba 6 desde el SQL Editor:
  `UPDATE sesion_entrenamiento SET comentario = 'x' WHERE fecha < current_date - 31;` debe dar el error RF-10.
