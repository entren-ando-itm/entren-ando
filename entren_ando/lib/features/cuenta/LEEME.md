# features/cuenta

Dueño: Pablo. Historias: ENT-41 (registro e inicio de sesión), ENT-42 (aviso de privacidad),
ENT-43 (ajustes y cerrar sesión), ENT-51 (eliminar mi cuenta y mis datos) y ENT-52 (Premium simulado).

Cuando exista el inicio de sesión, `usuarioActualIdProvider` (lib/core/db/usuario_actual.dart)
debe devolver el id del usuario que entró. Las demás pantallas ya lo usan.
