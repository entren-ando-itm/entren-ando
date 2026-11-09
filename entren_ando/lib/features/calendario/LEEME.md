# features/calendario

Dueña: Paola. Historias: ENT-60 (calendario semáforo mensual), ENT-70 (override con bloqueo de 30 días)
y ENT-71 (resumen de progreso del mes).

Los colores están en lib/core/tema/colores_semaforo.dart y los círculos de cada día en `CirculoDia` y
`PuntoSemaforo` (lib/core/componentes/semaforo.dart). `pantalla_calendario.dart` trae el ejemplo de la
hoja "tocar un día" del lienzo con `mostrarHojaInferior`; guardar el cambio es de ENT-70.

Los datos demo traen días completos, parciales, de descanso, uno marcado después (override) y días sin
registro, dentro y fuera de los últimos 30 días, para probar el bloqueo de RF-10.
