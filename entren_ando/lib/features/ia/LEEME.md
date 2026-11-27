# features/ia

Dueño: Axel. Historias: ENT-57 (función de IA en Supabase), ENT-58 (generar la rutina inicial),
ENT-68 (feedback periódico) y ENT-69 (pantalla de mensajes).

La app nunca llama a la IA directamente: siempre pasa por una función de Supabase, que guarda
la llave de Gemini. Sin red, estas pantallas se desactivan (RNF-02).

## rutina/ (ENT-58)

| Archivo | Para qué |
| --- | --- |
| `rutina_ia_repositorio.dart` | Arma la entrada (sin alias, nombre ni correo), llama a `generar-rutina` con `ServicioRutinaIa`, convierte la respuesta en `PropuestaRutina` y la guarda |
| `pantalla_rutina_ia.dart` | Carga (hasta 30 s), vista previa editable en memoria y guardado con RN-01 |

* Se entra desde Mis ciclos → "Generar con IA" (ruta `/perfil/ciclos/ia`), con `BotonConRed`.
* **No se guarda nada hasta "Guardar rutina".** Se guarda con `RutinasRepositorio.crearCicloCompleto`:
  ciclo con `origen = 'ia'` e `id_solicitud`, sus 7 días, ejercicios y alternativas.
* La `solicitud_ia` local lleva el mismo id que la nube (decisión 13); el motor de sync no la sube.
* Necesita una sesión de Supabase. Con el demo sin `DEMO_PASSWORD` muestra un error claro y
  ofrece crear la rutina a mano.
* En pruebas se cambia la IA con `servicioRutinaIaProvider` o `rutinaIaRepositorioProvider`.
