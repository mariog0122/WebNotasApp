-- Migration: 20260907203000_institution_ai_pgcrypto.sql
-- Purpose: Enable pgcrypto extension and provide symmetric encryption/decryption functions for AI API keys in institution_ai_settings.
-- Resolves: FINDING-009 (P3 - Seguridad/Nomenclatura: Cifrado simétrico de claves API)

-- 1. Enable pgcrypto extension in extensions schema
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2. Function to symmetrically encrypt an AI API key using AES-256
CREATE OR REPLACE FUNCTION public.encrypt_ai_api_key(
  p_key text,
  p_passphrase text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public, pg_temp
AS $$
BEGIN
  IF p_key IS NULL OR btrim(p_key) = '' THEN
    RETURN NULL;
  END IF;
  RETURN extensions.armor(extensions.pgp_sym_encrypt(p_key, p_passphrase, 'cipher-algo=aes256'));
END;
$$;

-- 3. Function to symmetrically decrypt an AI API key using AES-256
CREATE OR REPLACE FUNCTION public.decrypt_ai_api_key(
  p_armored_cipher text,
  p_passphrase text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public, pg_temp
AS $$
BEGIN
  IF p_armored_cipher IS NULL OR btrim(p_armored_cipher) = '' THEN
    RETURN NULL;
  END IF;
  RETURN extensions.pgp_sym_decrypt(extensions.dearmor(p_armored_cipher), p_passphrase);
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

-- 4. Restrict execution privileges: Only service_role can call encryption/decryption
REVOKE ALL ON FUNCTION public.encrypt_ai_api_key(text, text) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.encrypt_ai_api_key(text, text) TO service_role;

REVOKE ALL ON FUNCTION public.decrypt_ai_api_key(text, text) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decrypt_ai_api_key(text, text) TO service_role;
