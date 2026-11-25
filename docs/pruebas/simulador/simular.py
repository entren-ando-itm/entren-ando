"""Simula MotorSync.subirPendientes(todo=...) contra el PostgreSQL local con RLS."""
import re, sqlite3, subprocess, sys, json, os

# Raíz del repositorio (este archivo está en docs/pruebas/simulador).
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
DEMO = '00000000-0000-0000-0000-000000000001'

def tablas_de_dart():
    src = open(f'{REPO}/entren_ando/lib/core/sync/motor_sync.dart').read()
    bloque = src[src.index('static const List<TablaSync> tablas = ['):]
    bloque = bloque[:bloque.index('\n  ];')]
    tablas = []
    for m in re.finditer(r"TablaSync\(\s*'(\w+)',\s*\[([^\]]*)\](.*?)\),\n", bloque + '\n', re.S):
        nombre, llaves, resto = m.group(1), re.findall(r"'(\w+)'", m.group(2)), m.group(3)
        b = re.search(r"booleanas:\s*\[([^\]]*)\]", resto)
        d = re.search(r"dueno:\s*((?:'[^']*'\s*)+)", resto)
        dueno = ''.join(re.findall(r"'([^']*)'", d.group(1))) if d else 'id_usuario = ?'
        tablas.append(dict(nombre=nombre, llaves=llaves, booleanas=re.findall(r"'(\w+)'", b.group(1)) if b else [], dueno=dueno))
    return tablas

def lit(v):
    if v is None: return 'NULL'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)): return repr(v)
    return "'" + str(v).replace("'", "''") + "'"

def psql(sql):
    script = f"SET ROLE authenticated;\nSELECT set_config('request.jwt.claim.sub', '{DEMO}', false) \\g /dev/null\n{sql}\n"
    r = subprocess.run(['psql', '-h', '/tmp', '-p', '54329', '-U', 'postgres', '-d', 'postgres', '-q', '-v', 'ON_ERROR_STOP=1'],
                       input=script, capture_output=True, text=True)
    return r.returncode == 0, r.stderr.strip()

def psql_admin(sql):
    return subprocess.run(['psql', '-h', '/tmp', '-p', '54329', '-U', 'postgres', '-d', 'postgres', '-At', '-c', sql], capture_output=True, text=True).stdout.strip()

def a_nube(t, fila):
    f = dict(fila)
    if t['nombre'] == 'usuario':
        f.pop('id_plan', None)
    for c in ['eliminado', *t['booleanas']]:
        if isinstance(f.get(c), (int, float)): f[c] = f[c] != 0
    f['pendiente_sync'] = False
    return f

def upsert(t, lote):
    cols = list(lote[0].keys())
    vals = ',\n'.join('(' + ', '.join(lit(f[c]) for c in cols) + ')' for f in lote)
    upd = ', '.join(f'{c} = EXCLUDED.{c}' for c in cols if c not in t['llaves'])
    return psql(f"INSERT INTO {t['nombre']} ({', '.join(cols)}) VALUES {vals} ON CONFLICT ({', '.join(t['llaves'])}) DO UPDATE SET {upd};")

def sincronizar(bd, todo):
    tablas = tablas_de_dart()
    por = {}
    for t in tablas:
        q = f"SELECT * FROM {t['nombre']} WHERE {'' if todo else 'pendiente_sync = 1 AND '}{t['dueno']} ORDER BY actualizado_en"
        por[t['nombre']] = [dict(r) for r in bd.execute(q, [DEMO])]
    if not any(por.values()): return 0, 0, {}
    if not por['usuario']:
        por['usuario'] = [dict(r) for r in bd.execute('SELECT * FROM usuario WHERE id_usuario = ?', [DEMO])]
    subidas = rech = 0; errores = {}
    for t in tablas:
        filas = por[t['nombre']]
        for i in range(0, len(filas), 100):
            lote = filas[i:i+100]
            ok, err = upsert(t, [a_nube(t, f) for f in lote])
            if ok:
                marcar(bd, t, lote); subidas += len(lote); continue
            for f in lote:
                ok, err = upsert(t, [a_nube(t, f)])
                if ok: marcar(bd, t, [f]); subidas += 1
                else:
                    rech += 1; errores.setdefault(t['nombre'], err.splitlines()[0])
    return subidas, rech, errores

def marcar(bd, t, lote):
    donde = ' AND '.join(f'{c} = ?' for c in t['llaves'])
    for f in lote:
        bd.execute(f"UPDATE {t['nombre']} SET pendiente_sync = 0 WHERE {donde} AND actualizado_en = ?", [*(f[c] for c in t['llaves']), f['actualizado_en']])
    bd.commit()

def nueva_bd():
    bd = sqlite3.connect(':memory:'); bd.row_factory = sqlite3.Row
    bd.execute('PRAGMA foreign_keys = ON')
    bd.executescript(open(f'{REPO}/entren_ando/lib/core/db/esquema.sql').read())
    bd.executescript(open(f'{REPO}/entren_ando/lib/core/db/catalogo_semilla.sql').read())
    bd.executescript(open(f'{REPO}/entren_ando/lib/core/db/datos_prueba.sql').read())
    return bd

if __name__ == '__main__':
    bd = nueva_bd()
    total_local = sum(bd.execute(f"SELECT COUNT(*) FROM {t['nombre']} WHERE {t['dueno']}", [DEMO]).fetchone()[0] for t in tablas_de_dart())
    print('Tablas leídas de motor_sync.dart:', len(tablas_de_dart()), '· filas demo en el celular:', total_local)
    for vuelta in (1, 2):
        s, r, e = sincronizar(bd, todo=True)
        print(f'"Subir también los datos de prueba" vuelta {vuelta}: subidas={s} rechazadas={r}', json.dumps(e, ensure_ascii=False) if e else '')
    print('Filas en la nube por tabla:')
    for t in tablas_de_dart():
        print(f"  {t['nombre']}: {psql_admin('SELECT count(*) FROM ' + t['nombre'])}")
