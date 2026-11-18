# features/rutinas

Dueño: Axel. Historias: ENT-47 (ciclos editables con límite del plan gratuito) y ENT-48
(alternativas por ejercicio). El catálogo con alias (ENT-17) vive en `lib/features/perfil/catalogo`.

## Qué hay

| Archivo | Para qué |
| --- | --- |
| `rutinas_repositorio.dart` | `RutinasRepositorio`: ciclos, sus 7 días y los ejercicios programados. `ValidarRutina` con las reglas de los CHECK |
| `rutinas_proveedores.dart` | Proveedores de Riverpod, `refrescarRutinas(ref)` y `FechaCiclo` (dd/mm/aaaa ↔ ISO) |
| `hoja_limite_ciclos.dart` | Hoja del límite RN-01: archivar un ciclo activo o ver Premium |
| `pantalla_ciclos.dart` | Mis ciclos (activos y archivados) y la hoja para crear o editar un ciclo |
| `pantalla_ciclo.dart` | Un ciclo con sus 7 días; archivar o reactivar |
| `pantalla_editor_dia.dart` | Editor de un día: rutina o descanso, nombre y ejercicios del catálogo |

## Reglas

* **RN-01:** el límite de ciclos activos se lee de `plan.max_ciclos_activos` (NULL = ilimitado),
  nunca con un `if` de plan gratuito.
* **Los ciclos no se borran:** se archivan (`estado = 'archivado'`). Un ciclo archivado es de solo
  lectura; el repositorio lanza `CicloSoloLectura` si se intenta editar.
* Cada ciclo tiene exactamente 7 días (`dia_rutina`, único por ciclo y día de la semana). Se crean
  todos como descanso.
* Quitar un ejercicio marca `eliminado = 1` en él y en sus alternativas, y renumera `orden`.
* El nombre de cada ejercicio usa `CatalogoRepositorio.nombreVisible` (alias); a la IA se manda
  `id_ejercicio` y `nombre_oficial`.
* Hoy debe usar `RutinasRepositorio.consultaCicloParaHoy` (el activo con `fecha_inicio` más reciente).
