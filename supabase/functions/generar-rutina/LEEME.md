# Función generar-rutina (ENT-57)

Dueño: Axel. La app (ENT-58) la llama para que Gemini proponga una semana de rutina. La app
**nunca** llama a Gemini directamente ni conoce su llave (decisión 5 de la bitácora).

| Archivo | Para qué |
| --- | --- |
| `index.ts` | La función: valida el JWT, registra `solicitud_ia`, llama a Gemini y responde |
| `logica.ts` | Prompt, esquema JSON, validación de ids, reintento y mensajes de error (sin red) |
| `logica_test.ts` | Pruebas con Gemini simulado: `deno test supabase/functions/generar-rutina` |

## Qué recibe (POST, con `Authorization: Bearer <token del usuario>`)

```json
{
  "perfil": { "objetivo": "hipertrofia", "nivel_experiencia": "intermedio", "dias_por_semana": 4, "notas_lesiones": null },
  "medicion": { "peso_kg": 74.6, "estatura_cm": 175, "porcentaje_grasa": null },
  "equipo": [2, 5],
  "catalogo": [{ "id_ejercicio": 1, "nombre_oficial": "Sentadilla con barra" }]
}
```

Nunca se manda el alias, el nombre ni el correo del usuario. El catálogo va filtrado por el equipo
del usuario, solo con `id_ejercicio` y `nombre_oficial`.

## Qué responde

* **200**: `{ id_solicitud, rutina: { nombre_ciclo, dias: [...] }, descartados, intentos }`.
  * `dias` siempre trae los 7 (1 = lunes ... 7 = domingo). Cada uno lleva `dia_semana`, `nombre`,
    `es_descanso` y `ejercicios`.
  * Cada ejercicio lleva `id_ejercicio`, `series`, `reps`, `peso_kg` (o null), `descanso_seg` y
    `alternativas` (hasta 3 id).
  * La app guarda el ciclo con ese `id_solicitud` (decisión 13).
* **Error**: `{ error: "mensaje en español", id_solicitud? }`.

| Código | Cuándo |
| --- | --- |
| 400 | Faltan datos del perfil |
| 401 | Sin sesión |
| 429 | Se acabó la cuota de Gemini |
| 500 | Falta configurar la llave |
| 502 | Gemini respondió algo que no se pudo leer |
| 504 | Gemini no respondió a tiempo |

## Reglas

* Solo cuentan los `id_ejercicio` que mandó la app **y** que existen en la tabla `ejercicio` de la
  nube.
* Si Gemini inventa un id, se reintenta **una vez** avisándole cuáles eran. En el segundo intento
  esos ids se descartan y se devuelven en `descartados`.
* Cada llamada crea una fila en `solicitud_ia` (`tipo = 'rutina'`): pasa de `pendiente` a
  `completada` o `fallida`. Se escribe con la llave de servicio porque la app no puede (RLS,
  decisión 7).
* Gemini tiene 13 s por intento para que todo quepa en los 30 s que espera la app.

## Publicarla (lo hace quien tenga acceso al proyecto de Supabase)

Las llaves se escriben **en tu terminal**, nunca en el chat ni en el código.

1. Instala la CLI con `npm i -g supabase` (o con Scoop) e inicia sesión con `supabase login`.
2. Pon la llave de Gemini como secreto (ENT-28): `supabase secrets set GEMINI_API_KEY=<tu llave> --project-ref <ref>`.
   * Opcional: `GEMINI_MODELO` para cambiar de modelo. Por defecto usa `gemini-2.5-flash`.
3. Publica: `supabase functions deploy generar-rutina --project-ref <ref>`.

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` ya los pone Supabase en la
función; no se configuran.

## Probarla con curl

1. Saca el token del usuario demo. La contraseña la escribes tú en la terminal:

   ```bash
   curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d '{"email":"demo@entrenando.test","password":"<contraseña>"}'
   ```

2. Llama la función con ese `access_token`:

   ```bash
   curl -s "$SUPABASE_URL/functions/v1/generar-rutina" -H "Authorization: Bearer <access_token>" -H "Content-Type: application/json" -d @entrada.json
   ```

3. Revisa en Supabase → Table Editor → `solicitud_ia` que quedó la fila con `estado = completada`.
