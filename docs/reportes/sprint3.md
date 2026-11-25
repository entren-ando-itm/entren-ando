# Reporte del Sprint 3 · Calendario e IA

**Proyecto:** Entren-Ando · Ingeniería de Software, Tecnológico de Morelia
**Sprint:** 3 de 4 · del lunes 23 al domingo 29 de noviembre de 2026 · revisión el lunes 30
**Scrum Master:** Ángel Pedraza Contreras · **Product Owner:** Pablo Gallegos
**Corte:** lunes 23 de noviembre de 2026 (día 1 del sprint). Datos tomados del tablero de Jira y de
GitHub ese día. Se actualiza al cierre del sprint para la revisión.

---

## 1. Objetivo del sprint

> Calendario semáforo, rutina generada con IA, Premium de prueba y sincronización completa entre el
> celular y la nube.

**¿Se cumplió?** Todavía no (es el primer día). Al corte, la sincronización completa ya está en
revisión; el calendario, la rutina con IA y Premium están por hacer.

## 2. Historias del sprint

| Clave | Historia | Responsable | Puntos | Estado al corte | Evidencia |
| --- | --- | --- | --- | --- | --- |
| ENT-51 | Eliminar mi cuenta y mis datos | Pablo | 3 | Por hacer | — |
| ENT-52 | Premium de prueba con compra simulada | Pablo | 4 | Por hacer | — |
| ENT-53 | Sincronización 2: bajar cambios, conflictos y segundo plano | Ángel | 4 | En revisión | PR #19 |
| ENT-54 | Indicador de sincronización y botón Sincronizar ahora | Ángel | 1 | En revisión | PR #20 |
| ENT-55 | Pruebas de cifrado y sincronización | Ángel | 2 | En revisión | PR #21 |
| ENT-56 | Reporte del Sprint 3 | Ángel | 0 | En revisión | este documento |
| ENT-57 | Función de IA en Supabase para generar rutinas | Axel | 3 | Por hacer | — |
| ENT-58 | Generar la rutina inicial con IA y editarla antes de guardar | Axel | 4 | Por hacer | — |
| ENT-59 | Sustituir un ejercicio solo por hoy | Paola | 3 | Por hacer | — |
| ENT-60 | Calendario semáforo mensual | Paola | 4 | Por hacer | — |

**Pendientes del Sprint 2 que siguen abiertos:** ENT-41 (En curso), ENT-42 y ENT-43 (Por hacer), de
Pablo. Están juntas en el PR #18 (cuenta: inicio de sesión, aviso de privacidad y cerrar sesión).

**Resumen (10 tarjetas, 28 puntos):**

| Estado | Tarjetas | Puntos |
| --- | --- | --- |
| Hecho | 0 | 0 |
| En revisión | 4 (ENT-53 a ENT-56) | 7 |
| En curso | 0 | 0 |
| Por hacer | 6 | 21 |

### Lo que ya está en revisión

* **ENT-53 · Sincronización 2 (PR #19).** La app baja de Supabase lo que cambió en la nube; en un
  conflicto gana el cambio más reciente; sincroniza sola cada 15 minutos con red (workmanager), y el
  servidor rechaza cambios a sesiones de más de 30 días (RF-10, `supabase/ajustes_ent53.sql`).
* **ENT-54 · Indicador de sincronización (PR #20).** Perfil → Respaldo en la nube: icono con el estado
  (respaldado, cambios por subir, sincronizando, sin respaldo), la última sincronización y el botón
  Sincronizar ahora (desactivado sin red).
* **ENT-55 · Pruebas de cifrado y sincronización (PR #21).** `docs/pruebas/cifrado_y_sync.md`: las
  pruebas de sync sin red, conflictos, borrado, RLS y regla de 30 días pasan; faltan las capturas del
  emulador.

`flutter analyze` (sin errores) y `flutter test` (82 pruebas) pasan con los cambios de ENT-53 y ENT-54.

## 3. Puntos completados (velocidad)

Comprometidos: **28 puntos**. Terminados al corte: **0**; en revisión: **7**.

| Sprint | Puntos comprometidos | Puntos terminados |
| --- | --- | --- |
| Sprint 2 | sin puntos en Jira | — |
| Sprint 3 | 28 | *al cierre* |

## 4. Gráfica de trabajo pendiente (burndown)

Al corte el Sprint 3 aparece en Jira como **futuro** (no iniciado), así que el burndown todavía no se
genera.

*Al cierre: Jira → Informes → Gráfico de evolución del sprint, y pegar aquí la imagen.*

## 5. Impedimentos

| Impedimento | Efecto | Qué se hizo o qué falta |
| --- | --- | --- |
| El Sprint 3 no está iniciado en Jira | Sin burndown ni informe del sprint | Iniciar el sprint en el tablero (y cerrar el Sprint 2) |
| Ángel no tiene permisos en el proyecto de Supabase | No puede correr `ajustes_ent53.sql` ni ver las tablas | Pablo corre el script; dar acceso de desarrollador a Ángel |
| La cuenta (ENT-41 a ENT-43) sigue abierta del Sprint 2 | La sincronización se prueba solo con el usuario demo | Revisar y unir el PR #18 |
| PR #20 y #21 dependen del #19 | No se pueden unir antes | Revisar primero el #19 |
| PR #13 (ENT-22, Gradle) abierto | — | Revisarlo o cerrarlo |

## 6. Retrospectiva

*Pendiente: se llena con lo que acuerde el equipo en la retrospectiva del cierre del sprint.*

* **¿Qué funcionó?**
* **¿Qué no funcionó?**
* **Acuerdos para el Sprint 4:**

---

*Reporte de ENT-56. Fuentes: tablero de Jira del proyecto ENT y Pull Requests de
`entren-ando-itm/entren-ando` al 23 de noviembre de 2026.*
