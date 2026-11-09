# features/ia

Dueño: Axel. Historias: ENT-57 (función de IA en Supabase), ENT-58 (generar la rutina inicial),
ENT-68 (feedback periódico) y ENT-69 (pantalla de mensajes).

La app nunca llama a la IA directamente: siempre pasa por una función de Supabase, que guarda
la llave de Gemini. Sin red, estas pantallas se desactivan (RNF-02).
