-- Keep the master encryption key in Supabase Vault. Vault encrypts it with a
-- platform-managed key that is separate from database backups.
do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'education_ai_key_encryption_secret') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(48), 'hex'),
      'education_ai_key_encryption_secret',
      'Master key used only by server-side AI credential RPCs'
    );
  end if;
end;
$$;

create or replace function public.encrypt_ai_api_key(p_key text)
returns text language plpgsql security definer
set search_path = pg_catalog, extensions, public, vault as $$
declare master_key text;
begin
  if p_key is null or btrim(p_key) = '' then return null; end if;
  select decrypted_secret into master_key
  from vault.decrypted_secrets
  where name = 'education_ai_key_encryption_secret'
  limit 1;
  if master_key is null or length(master_key) < 64 then
    raise exception 'AI encryption key is unavailable';
  end if;
  return extensions.armor(extensions.pgp_sym_encrypt(p_key, master_key, 'cipher-algo=aes256'));
end;
$$;

create or replace function public.decrypt_ai_api_key(p_armored_cipher text)
returns text language plpgsql security definer
set search_path = pg_catalog, extensions, public, vault as $$
declare master_key text;
begin
  if p_armored_cipher is null or btrim(p_armored_cipher) = '' then return null; end if;
  select decrypted_secret into master_key
  from vault.decrypted_secrets
  where name = 'education_ai_key_encryption_secret'
  limit 1;
  if master_key is null or length(master_key) < 64 then return null; end if;
  return extensions.pgp_sym_decrypt(extensions.dearmor(p_armored_cipher), master_key);
exception when others then
  return null;
end;
$$;

revoke all on function public.encrypt_ai_api_key(text) from public, anon, authenticated;
grant execute on function public.encrypt_ai_api_key(text) to service_role;
revoke all on function public.decrypt_ai_api_key(text) from public, anon, authenticated;
grant execute on function public.decrypt_ai_api_key(text) to service_role;

drop function if exists public.encrypt_ai_api_key(text, text);
drop function if exists public.decrypt_ai_api_key(text, text);
