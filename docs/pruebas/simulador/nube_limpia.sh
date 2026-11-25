#!/bin/bash
# Crea una "nube" limpia: PostgreSQL 16 local que imita Supabase (roles, auth.uid() y RLS).
# Uso (Linux o WSL, como root): bash nube_limpia.sh
# Corre esquema, catálogo, políticas y los ajustes de ENT-44 y ENT-53.
set -e
PGBIN=/usr/lib/postgresql/16/bin; D=/tmp/pgsync
su postgres -c "$PGBIN/pg_ctl -D $D/data -m fast stop" >/dev/null 2>&1 || true
rm -rf $D && mkdir -p $D && chown postgres $D
su postgres -c "$PGBIN/initdb -D $D/data -U postgres -A trust >/dev/null"
su postgres -c "$PGBIN/pg_ctl -D $D/data -o '-p 54329 -k /tmp' -l $D/log start >/dev/null"
sleep 2
P="psql -h /tmp -p 54329 -U postgres -d postgres -v ON_ERROR_STOP=1 -q"
AQUI="$(cd "$(dirname "$0")" && pwd)"
cd "$AQUI/../../.."
$P -f "$AQUI/auth_mock.sql"
$P -f supabase/esquema.sql
$P -f docs/12_catalogo_semilla.sql
$P -f supabase/politicas.sql
$P -f supabase/ajustes_ent44.sql >/dev/null
$P -f supabase/ajustes_ent53.sql >/dev/null 2>&1
