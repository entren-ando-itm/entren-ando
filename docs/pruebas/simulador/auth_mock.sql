-- Imitación mínima de Supabase: roles, esquema auth y auth.uid()
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users (instance_id uuid, id uuid PRIMARY KEY, email text, aud text, role text, encrypted_password text);
CREATE TABLE auth.identities (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), provider_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, identity_data jsonb NOT NULL, provider text NOT NULL,
  UNIQUE (provider_id, provider));
CREATE TABLE auth.sessions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE auth.one_time_tokens (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, token_hash text);
CREATE TABLE auth.mfa_factors (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
-- El demo como lo creó el dashboard (id viejo), con una sesión y un token abiertos
INSERT INTO auth.users (id, email, aud, role) VALUES ('799d887c-d5e1-4e58-92ec-2d8013b3d2b0', 'demo@entrenando.test', 'authenticated', 'authenticated');
INSERT INTO auth.identities (provider_id, user_id, identity_data, provider)
VALUES ('799d887c-d5e1-4e58-92ec-2d8013b3d2b0', '799d887c-d5e1-4e58-92ec-2d8013b3d2b0',
        '{"sub": "799d887c-d5e1-4e58-92ec-2d8013b3d2b0", "email": "demo@entrenando.test"}', 'email');
INSERT INTO auth.sessions (user_id) VALUES ('799d887c-d5e1-4e58-92ec-2d8013b3d2b0');
INSERT INTO auth.one_time_tokens (user_id, token_hash) VALUES ('799d887c-d5e1-4e58-92ec-2d8013b3d2b0', 'x');
