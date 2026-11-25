# Premium de prueba: activar y cancelar (ENT-93 y ENT-95)

Desde la raíz del repositorio, aplica `supabase/ajustes_ent52.sql` en el SQL Editor del proyecto
Supabase de prueba, después del esquema, el catálogo y las políticas. Publica la función en ese
proyecto con `supabase functions deploy premium-prueba`. Está encendida por defecto; para apagarla
usa `supabase secrets set PREMIUM_PRUEBA_HABILITADA=false`. Auth y la llave de servicio se leen de
las variables del entorno de Supabase. La integración con la tienda real queda pendiente.

La app de prueba envía un POST con su sesión de Supabase. La función toma el usuario de la
sesión. El cuerpo es `{"accion": "activar"}` (si no se manda, activa) o `{"accion": "cancelar"}`. La cuenta debe tener una fila en `usuario` en la nube.
Para probar con el demo, inicia la sesión de Supabase del demo y sincroniza primero.

La respuesta HTTP 200 contiene `id_plan` (2), `id_suscripcion` (UUID) y `fecha_expiracion`
(ISO 8601). Repetir la llamada durante la vigencia devuelve la misma suscripción y fecha.
Un 401 pide iniciar sesión, un 403 indica que las pruebas están desactivadas y un 409 pide
sincronizar primero la cuenta. Tras un error temporal se puede repetir la llamada.

ENT-94 usa el plan confirmado para actualizar la copia local. El motor descarga suscripciones
y eventos de pago y solo sube las columnas de usuario que controla el celular. Al aplicar estos
permisos, las versiones anteriores que todavía suben `id_plan` necesitan la actualización de la app.

Para verificar la transacción, los permisos y una edición sin conexión, ejecuta
`psql -v ON_ERROR_STOP=1 -f docs/pruebas/simulador/premium_prueba.sql` contra el simulador
preparado con `nube_limpia.sh`. La prueba revierte sus datos al terminar.

## Cancelar y vencer (ENT-95)

* `{"accion": "cancelar"}` marca la suscripción como `cancelada`, registra el evento `cancelacion` y
  devuelve `{"id_plan": 1}`. La app archiva en el celular los ciclos que sobran y deja activo el
  más reciente (`PlanLocal.ajustarCiclosAlPlan`). Se puede volver a activar después.
* `vencer_premium_prueba()` corre cada día con pg_cron (06:15 UTC): marca `expirada` la prueba que
  pasó sus 30 días y regresa la cuenta a Gratuito. El celular hace lo mismo sin red al abrir la app
  (`PlanLocal.revisarVencimiento`) y después de cada bajada.
* Si pg_cron no está habilitado en el proyecto, actívalo en Database → Extensions y vuelve a correr
  `ajustes_ent52.sql`.
