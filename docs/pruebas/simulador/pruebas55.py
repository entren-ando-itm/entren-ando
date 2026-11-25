"""ENT-55: pruebas 2 a 6 contra la imitación local de Supabase (PG 16 + RLS + ajustes 44 y 53)."""
import subprocess, uuid, sqlite3
import simular as s, bajar as b

admin = s.psql_admin
AHORA = "strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'"

def como(usuario, sql):
    """Corre SQL con el rol authenticated y auth.uid() = usuario, como la app con su sesión."""
    script = (f"SET ROLE authenticated;\nSELECT set_config('request.jwt.claim.sub', '{usuario}', false) \\g /dev/null\n{sql}\n")
    r = subprocess.run(['psql', '-h', '/tmp', '-p', '54329', '-U', 'postgres', '-d', 'postgres', '-qAt', '-v', 'ON_ERROR_STOP=1'],
                       input=script, capture_output=True, text=True)
    if r.returncode != 0: return 'ERROR: ' + next(l for l in r.stderr.splitlines() if 'ERROR:' in l).split('ERROR:')[-1].strip()
    return r.stdout.strip().replace('\n', ' / ') or 'listo'

bd = s.nueva_bd()
print('Preparación: datos de prueba subidos a la nube (subidas, rechazadas):', s.sincronizar(bd, todo=True)[:2])
b.bajar(bd, completa=True)

print('\n== Prueba 2: un cambio hecho sin red aparece en la nube al volver la red ==')
comida = str(uuid.uuid4())
bd.execute(f"INSERT INTO registro_comida (id_comida, id_usuario, descripcion, calorias, origen) VALUES (?, ?, 'Prueba ENT-55: avena', 350, 'manual')", [comida, s.DEMO]); bd.commit()
print('Sin red: en el celular pendiente_sync =', bd.execute('SELECT pendiente_sync FROM registro_comida WHERE id_comida=?', [comida]).fetchone()[0],
      '| en la nube:', admin(f"SELECT count(*) FROM registro_comida WHERE id_comida = '{comida}'"), 'fila(s)')
print('Vuelve la red → sincronizar:', b.subir_con_rf10(bd), '(subidas, descartadas RF-10, rechazadas)')
print('En la nube:', admin(f"SELECT descripcion || ' · ' || calorias || ' kcal' FROM registro_comida WHERE id_comida = '{comida}'"),
      '| en el celular pendiente_sync =', bd.execute('SELECT pendiente_sync FROM registro_comida WHERE id_comida=?', [comida]).fetchone()[0])

print('\n== Prueba 3: en un conflicto gana el cambio más reciente ==')
admin(f"UPDATE registro_comida SET calorias = 400, actualizado_en = now() - interval '10 minutes' WHERE id_comida = '{comida}'")
bd.execute(f"UPDATE registro_comida SET calorias = 380, pendiente_sync = 1, actualizado_en = {AHORA} WHERE id_comida = ?", [comida]); bd.commit()
b.bajar(bd)
print('a) Celular más reciente (380) vs nube (400, hace 10 min) → celular =', bd.execute('SELECT calorias FROM registro_comida WHERE id_comida=?', [comida]).fetchone()[0],
      '→ subir', b.subir_con_rf10(bd), '→ nube =', admin(f"SELECT calorias FROM registro_comida WHERE id_comida = '{comida}'"))
bd.execute("UPDATE registro_comida SET calorias = 390, pendiente_sync = 1, actualizado_en = '2026-11-01T08:00:00-06:00' WHERE id_comida = ?", [comida]); bd.commit()
admin(f"UPDATE registro_comida SET calorias = 420, actualizado_en = now() WHERE id_comida = '{comida}'")
b.bajar(bd)
print('b) Nube más reciente (420) vs celular (390, viejo) → celular =',
      tuple(bd.execute('SELECT calorias, pendiente_sync FROM registro_comida WHERE id_comida=?', [comida]).fetchone()), '(calorías, pendiente_sync)')

print('\n== Prueba 4: un borrado (eliminado = 1) se sincroniza ==')
sesion = bd.execute("SELECT id_sesion FROM sesion_entrenamiento WHERE fecha >= date('now', '-6 hours', '-5 days') AND eliminado = 0 AND estado <> 'descanso' ORDER BY fecha DESC LIMIT 1").fetchone()[0]
regs = [r[0] for r in bd.execute('SELECT id_registro FROM registro_ejercicio WHERE id_sesion = ?', [sesion])]
marcas = ','.join('?' * len(regs))
bd.execute(f"UPDATE sesion_entrenamiento SET eliminado = 1, pendiente_sync = 1, actualizado_en = {AHORA} WHERE id_sesion = ?", [sesion])
bd.execute(f"UPDATE registro_ejercicio SET eliminado = 1, pendiente_sync = 1, actualizado_en = {AHORA} WHERE id_sesion = ?", [sesion])
bd.execute(f"UPDATE serie SET eliminado = 1, pendiente_sync = 1, actualizado_en = {AHORA} WHERE id_registro IN ({marcas})", regs)
bd.execute(f"UPDATE registro_comida SET eliminado = 1, pendiente_sync = 1, actualizado_en = {AHORA} WHERE id_comida = ?", [comida]); bd.commit()
print('Borrar en el celular 1 sesión (con', len(regs), 'registros y sus series) y 1 comida → subir:', b.subir_con_rf10(bd))
print('En la nube: sesión eliminado =', admin(f"SELECT eliminado FROM sesion_entrenamiento WHERE id_sesion = '{sesion}'"),
      '| registros eliminados =', admin(f"SELECT count(*) FILTER (WHERE eliminado) || ' de ' || count(*) FROM registro_ejercicio WHERE id_sesion = '{sesion}'"),
      '| series eliminadas =', admin(f"SELECT count(*) FILTER (WHERE se.eliminado) || ' de ' || count(*) FROM serie se JOIN registro_ejercicio r USING (id_registro) WHERE r.id_sesion = '{sesion}'"),
      '| comida eliminado =', admin(f"SELECT eliminado FROM registro_comida WHERE id_comida = '{comida}'"),
      '| filas borradas con DELETE: 0 (siguen', admin(f"SELECT count(*) FROM sesion_entrenamiento WHERE id_sesion = '{sesion}'"), 'fila)')
otro = sqlite3.connect(':memory:'); otro.row_factory = sqlite3.Row; otro.execute('PRAGMA foreign_keys = ON')
otro.executescript(open(f'{s.REPO}/entren_ando/lib/core/db/esquema.sql').read())
otro.executescript(open(f'{s.REPO}/entren_ando/lib/core/db/catalogo_semilla.sql').read())
b.MARCAS.clear(); b.bajar(otro)
print('Otro celular baja todo → la sesión borrada llega con eliminado =', otro.execute('SELECT eliminado FROM sesion_entrenamiento WHERE id_sesion=?', [sesion]).fetchone()[0],
      '(no aparece en pantallas que filtran eliminado = 0:', otro.execute('SELECT count(*) FROM sesion_entrenamiento WHERE id_sesion=? AND eliminado = 0', [sesion]).fetchone()[0], 'filas)')

print('\n== Prueba 5: un usuario no ve los datos de otro (RLS) ==')
intruso = str(uuid.uuid4())
admin(f"INSERT INTO auth.users (id, email, aud, role) VALUES ('{intruso}', 'otro@entrenando.test', 'authenticated', 'authenticated')")
print('Demo ve sus sesiones:', como(s.DEMO, 'SELECT count(*) FROM sesion_entrenamiento'),
      '| el otro usuario ve:', como(intruso, 'SELECT count(*) FROM sesion_entrenamiento'),
      '| comidas que ve el otro:', como(intruso, 'SELECT count(*) FROM registro_comida'),
      '| series que ve el otro:', como(intruso, 'SELECT count(*) FROM serie'))
print('El otro intenta cambiar una comida del demo → filas cambiadas:',
      como(intruso, f"WITH c AS (UPDATE registro_comida SET calorias = 1 WHERE id_comida = '{comida}' RETURNING 1) SELECT count(*) FROM c"),
      '| calorías en la nube siguen en', admin(f"SELECT calorias FROM registro_comida WHERE id_comida = '{comida}'"))
print('El otro intenta guardar una comida a nombre del demo →',
      como(intruso, f"INSERT INTO registro_comida (id_comida, id_usuario, descripcion, calorias, origen) VALUES (gen_random_uuid(), '{s.DEMO}', 'falsa', 1, 'manual')"))
print('Sin sesión (anon), consultar sesiones →', subprocess.run(['psql', '-h', '/tmp', '-p', '54329', '-U', 'postgres', '-d', 'postgres', '-qAt'],
      input='SET ROLE anon;\nSELECT count(*) FROM sesion_entrenamiento;\n', capture_output=True, text=True).stdout.strip() or 'sin permiso')

print('\n== Prueba 6: el servidor rechaza cambios a sesiones de más de 30 días (RF-10) ==')
vieja, fecha = admin("SELECT id_sesion || '|' || fecha FROM sesion_entrenamiento WHERE fecha < current_date - 31 AND NOT eliminado ORDER BY fecha LIMIT 1").split('|')
print('Sesión del', fecha, '— el demo intenta cambiarla directo en la nube →',
      como(s.DEMO, f"UPDATE sesion_entrenamiento SET comentario = 'cambio tardío' WHERE id_sesion = '{vieja}'"))
print('Código del error:', como(s.DEMO, f"DO $$ BEGIN UPDATE sesion_entrenamiento SET comentario = 'x' WHERE id_sesion = '{vieja}'; EXCEPTION WHEN SQLSTATE 'EA010' THEN RAISE NOTICE 'EA010'; END $$; SELECT 'EA010 capturado'"))
bd.execute(f"UPDATE sesion_entrenamiento SET comentario = 'cambio tardío', pendiente_sync = 1, actualizado_en = {AHORA} WHERE id_sesion = ?", [vieja]); bd.commit()
print('Desde el celular → subir (subidas, descartadas RF-10, rechazadas):', b.subir_con_rf10(bd),
      '| comentario en la nube:', repr(admin(f"SELECT coalesce(comentario, '') FROM sesion_entrenamiento WHERE id_sesion = '{vieja}'")),
      '| en el celular:', tuple(bd.execute('SELECT comentario, pendiente_sync FROM sesion_entrenamiento WHERE id_sesion=?', [vieja]).fetchone()))
reciente = admin("SELECT id_sesion FROM sesion_entrenamiento WHERE fecha >= current_date - 10 AND NOT eliminado LIMIT 1")
print('Control: sesión de hace menos de 30 días sí se cambia →',
      como(s.DEMO, f"WITH c AS (UPDATE sesion_entrenamiento SET comentario = 'ok' WHERE id_sesion = '{reciente}' RETURNING 1) SELECT count(*) || ' fila cambiada' FROM c"))
