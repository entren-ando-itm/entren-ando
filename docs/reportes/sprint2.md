# Reporte del Sprint 2 · Rutinas y cuenta

**Proyecto:** Entren-Ando · Ingeniería de Software, Tecnológico de Morelia
**Sprint:** 2 de 4 · del lunes 16 al domingo 22 de noviembre de 2026 (el lunes 16 fue día festivo)
**Scrum Master:** Ángel Pedraza Contreras · **Product Owner:** Pablo Gallegos
**Corte:** martes 17 de noviembre de 2026 (día 2 del sprint). Datos tomados del tablero de Jira y de
GitHub ese día. Se actualiza al cierre del sprint para la revisión.

---

## 1. Objetivo del sprint

> Registrar un entrenamiento completo sin internet sobre una rutina editable, con cuenta de usuario y
> subida de cambios a la nube.

**¿Se cumplió?** Todavía no (el sprint va a la mitad). Al corte hay avance en la subida a la nube y en
el registro de comidas, ambos en revisión; la cuenta de usuario, las rutinas editables y el registro
del entrenamiento siguen por hacer o en curso.

## 2. Historias del sprint

| Clave | Historia | Responsable | Estado al corte | Evidencia |
| --- | --- | --- | --- | --- |
| ENT-19 | Temporizador contextual con sonido y vibración *(viene del Sprint 1)* | Paola | En curso | PR #9 abierto desde el 11 nov |
| ENT-41 | Registro e inicio de sesión con correo y contraseña | Pablo | Por hacer | — |
| ENT-42 | Aceptar el aviso de privacidad al registrarse | Pablo | Por hacer | — |
| ENT-43 | Pantalla de ajustes con cerrar sesión | Pablo | Por hacer | — |
| ENT-44 | Sincronización 1: subir los cambios hechos sin internet | Ángel | En revisión | PR #11 |
| ENT-45 | Registro nutricional manual | Ángel | En revisión | PR #10 |
| ENT-46 | Reporte del Sprint 2 | Ángel | En curso | este documento |
| ENT-47 | Ciclos de rutina editables con límite del plan gratuito | Axel | Por hacer | — |
| ENT-48 | Alternativas preconfiguradas por ejercicio | Axel | Por hacer | — |
| ENT-49 | Bitácora rápida: precarga y marcar series | Paola | En curso | — |
| ENT-50 | Completar ejercicio y guardar la sesión del día | Paola | Por hacer | — |

**Resumen (11 tarjetas, contando ENT-19):**

| Estado | Historias y tareas | Subtareas del Sprint 2 (19) |
| --- | --- | --- |
| Hecho | 0 | 0 |
| En revisión | 2 (ENT-44, ENT-45) | 5 (ENT-78 a ENT-82) |
| En curso | 3 (ENT-19, ENT-46, ENT-49) | 2 (ENT-87, ENT-88) |
| Por hacer | 6 | 12 |

### Lo que ya está en revisión

* **ENT-45 · Registro nutricional manual (PR #10).** Pestaña Comidas con el total del día en calorías y
  macros, registro a mano, editar y borrar (se marca `eliminado = 1`). Funciona en modo avión.
* **ENT-44 · Sincronización 1 (PR #11).** Lo que se guarda sin internet se sube solo a Supabase al abrir
  la app, al volver la red y al iniciar sesión, con upsert por id en lotes de 100 (no duplica si se
  corta la red). Incluye `supabase/ajustes_ent44.sql`: zona horaria de Ciudad de México y el mismo id
  para el usuario demo en el celular y en Supabase.

## 3. Puntos completados (velocidad)

Las historias **no tienen puntos de historia en Jira**, así que no se puede calcular la velocidad en
puntos. Por número de tarjetas: **0 terminadas** al corte; **2 en revisión**.

*Al cierre del sprint: poner aquí puntos comprometidos y puntos terminados.*

## 4. Gráfica de trabajo pendiente (burndown)

Al corte **no se puede generar**: en Jira el Sprint 1 sigue activo y el Sprint 2 no se ha iniciado, y
el burndown solo cuenta desde que el sprint se inicia.

*Al cierre: Jira → Informes → Gráfico de evolución del sprint, y pegar aquí la imagen.*

## 5. Impedimentos

| Impedimento | Efecto | Qué se hizo o qué falta |
| --- | --- | --- |
| El Sprint 1 no se cerró en Jira y el Sprint 2 no se inició | Sin burndown ni informe del sprint | Cerrar el Sprint 1 (ENT-19 pasa al Sprint 2) e iniciar el Sprint 2 en el tablero |
| Las historias no tienen puntos de historia | No se mide la velocidad | Estimar en la planeación (la guía marca 7 puntos por persona por sprint) |
| PR #9 (ENT-19) abierto desde el 11 de noviembre | ENT-19 no se cierra y se arrastra del Sprint 1 | Revisarlo y unirlo, o pedir cambios |
| El inicio de sesión (ENT-41) aún no existe | La sincronización no se puede probar con un usuario real | Se prueba con el usuario demo desde Perfil → Modo de prueba → Nube y sincronización |
| El usuario demo tenía ids distintos en el celular y en Supabase | La seguridad (RLS) rechazaba todo lo que subía el demo | `supabase/ajustes_ent44.sql` le da a Supabase el mismo id (PR #11) |
| Lunes 16 festivo | Un día menos de clase; la planeación se movió al martes 17 | — |

## 6. Retrospectiva

*Pendiente: se llena con lo que acuerde el equipo en la retrospectiva del cierre del sprint.*

* **¿Qué funcionó?**
* **¿Qué no funcionó?**
* **Acuerdos para el Sprint 3:**

---

*Reporte de ENT-46. Fuentes: tablero de Jira del proyecto ENT y Pull Requests de
`entren-ando-itm/entren-ando` al 17 de noviembre de 2026.*
