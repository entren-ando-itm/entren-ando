# core/sync

Dueño: Ángel. Historias: ENT-44 (subir cambios) y ENT-53 (bajar cambios, conflictos y segundo plano).

Aquí va el motor de sincronización con Supabase:

* Sube las filas con `pendiente_sync = 1` y, cuando Supabase las confirma, las deja en 0.
  Es la única parte de la app que pone `pendiente_sync = 0`.
* Los borrados viajan como `eliminado = 1`.
* Los datos demo se crean con `pendiente_sync = 0`, así que no se suben.
