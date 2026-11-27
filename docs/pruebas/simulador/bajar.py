"""Réplica en Python de MotorSync.bajarCambios / _guardarDeNube / RF-10 (ENT-53)."""
import json, subprocess, re
from datetime import datetime
import simular as s

def tablas_bajar():
    src = open(f'{s.REPO}/entren_ando/lib/core/sync/motor_sync.dart').read()
    b = src[src.index('static const List<TablaSync> tablasBajar = ['):]
    b = b[:b.index('\n  ];')]
    return [dict(nombre=m.group(1), llaves=re.findall(r"'(\w+)'", m.group(2))) for m in re.finditer(r"TablaSync\('(\w+)', \[([^\]]*)\]\)", b)]

def nube(sql):
    """Consulta como el usuario demo (RLS), devuelve lista de dicts."""
    script = f"SET ROLE authenticated;\nSELECT set_config('request.jwt.claim.sub', '{s.DEMO}', false) \\g /dev/null\n\\pset format unaligned\n\\pset tuples_only on\nSELECT coalesce(json_agg(t), '[]') FROM ({sql}) t;\n"
    r = subprocess.run(['psql','-h','/tmp','-p','54329','-U','postgres','-d','postgres','-q'], input=script, capture_output=True, text=True)
    if r.returncode: raise RuntimeError(r.stderr)
    out = r.stdout.strip(); return json.loads(out[out.index('['):])

def parse(t): return datetime.fromisoformat(t) if t else None

def a_local(fila, cols):
    out = {}
    for c, v in fila.items():
        if c not in cols: continue
        out[c] = (1 if v else 0) if isinstance(v, bool) else (json.dumps(v) if isinstance(v, (dict, list)) else v)
    out['pendiente_sync'] = 0
    return out

def guardar_de_nube(bd, t, remota, forzar=False):
    cols = {r[1] for r in bd.execute(f"PRAGMA table_info({t['nombre']})")}
    donde = ' AND '.join(f'{c} = ?' for c in t['llaves'])
    local = bd.execute(f"SELECT actualizado_en, pendiente_sync FROM {t['nombre']} WHERE {donde}", [remota[c] for c in t['llaves']]).fetchone()
    if local and not forzar:
        cel, nub = parse(local[0]), parse(remota['actualizado_en'])
        if cel and nub:
            if (local[1] == 1 and cel > nub) or (local[1] != 1 and cel == nub):
                if t['nombre'] != 'usuario': return False
                cambios = bd.execute('UPDATE usuario SET id_plan = ? WHERE id_usuario = ? AND id_plan <> ?',
                                     (remota['id_plan'], remota['id_usuario'], remota['id_plan']))
                bd.commit()
                return cambios.rowcount > 0
    fila = a_local(remota, cols); cs = list(fila)
    upd = ', '.join(f'{c} = excluded.{c}' for c in cs if c not in t['llaves'])
    bd.execute(f"INSERT INTO {t['nombre']} ({', '.join(cs)}) VALUES ({', '.join('?'*len(cs))}) ON CONFLICT ({', '.join(t['llaves'])}) DO UPDATE SET {upd}", [fila[c] for c in cs])
    bd.commit(); return True

MARCAS = {}
def bajar(bd, completa=False):
    n = 0
    for t in tablas_bajar():
        desde = None if completa else MARCAS.get(t['nombre'])
        donde = f"WHERE actualizado_en >= '{desde}'" if desde and t['nombre'] != 'usuario' else ''
        orden = ', '.join(['actualizado_en', *t['llaves']])
        mas = desde
        for f in nube(f"SELECT * FROM {t['nombre']} {donde} ORDER BY {orden}"):
            if guardar_de_nube(bd, t, f): n += 1
            if mas is None or parse(f['actualizado_en']) > parse(mas): mas = f['actualizado_en']
        if mas: MARCAS[t['nombre']] = mas
    return n

def subir_con_rf10(bd):
    """subirPendientes + RF-10: si la nube responde EA010, se queda con la versión de la nube."""
    sub = desc = rech = 0
    for t in s.tablas_de_dart():
        filas = [dict(r) for r in bd.execute(f"SELECT * FROM {t['nombre']} WHERE pendiente_sync = 1 AND {t['dueno']}", [s.DEMO])]
        for f in filas:
            ok, err = s.upsert(t, [s.a_nube(t, f)])
            if ok: s.marcar(bd, t, [f]); sub += 1
            elif 'RF-10' in err:
                desc += 1
                remota = nube(f"SELECT * FROM {t['nombre']} WHERE " + ' AND '.join(f"{c} = '{f[c]}'" for c in t['llaves']))
                guardar_de_nube(bd, t, remota[0], forzar=True)
            else: rech += 1; print('   rechazo:', err.splitlines()[0])
    return sub, desc, rech
