/// Divide un archivo .sql en sentencias para ejecutarlas una por una.
///
/// Android solo ejecuta una sentencia por llamada, así que esquema.sql,
/// catalogo_semilla.sql y datos_prueba.sql se dividen aquí. Respeta los
/// textos entre comillas simples (aunque tengan punto y coma) y quita los
/// comentarios de línea (--) y de bloque.
class ScriptSql {
  ScriptSql._();

  static List<String> dividir(String script) {
    final sentencias = <String>[];
    final actual = StringBuffer();
    var enTexto = false;
    var i = 0;

    while (i < script.length) {
      final c = script[i];

      if (enTexto) {
        actual.write(c);
        if (c == "'") {
          // Dos comillas seguidas son una comilla dentro del texto.
          if (i + 1 < script.length && script[i + 1] == "'") {
            actual.write("'");
            i += 2;
            continue;
          }
          enTexto = false;
        }
        i++;
        continue;
      }

      if (c == "'") {
        enTexto = true;
        actual.write(c);
        i++;
        continue;
      }

      // Comentario de línea: se salta hasta el fin de la línea.
      if (c == '-' && i + 1 < script.length && script[i + 1] == '-') {
        final fin = script.indexOf('\n', i);
        if (fin == -1) break;
        i = fin;
        continue;
      }

      // Comentario de bloque.
      if (c == '/' && i + 1 < script.length && script[i + 1] == '*') {
        final fin = script.indexOf('*/', i + 2);
        if (fin == -1) break;
        i = fin + 2;
        continue;
      }

      if (c == ';') {
        final sentencia = actual.toString().trim();
        if (sentencia.isNotEmpty) sentencias.add(sentencia);
        actual.clear();
        i++;
        continue;
      }

      actual.write(c);
      i++;
    }

    final resto = actual.toString().trim();
    if (resto.isNotEmpty) sentencias.add(resto);
    return sentencias;
  }
}
