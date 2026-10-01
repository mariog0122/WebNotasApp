-- Apply the candidate pgcrypto migration inside the same BEGIN/ROLLBACK when testing an undeployed database.
begin;
do $$ declare encrypted text; begin
  encrypted := public.encrypt_ai_api_key('synthetic-api-key');
  if encrypted is null or encrypted='synthetic-api-key' or encrypted not like '-----BEGIN PGP MESSAGE%' then
    raise exception 'AI encryption did not produce an armored ciphertext';
  end if;
  if public.decrypt_ai_api_key(encrypted) is distinct from 'synthetic-api-key' then
    raise exception 'AI encryption round-trip failed';
  end if;
  if has_function_privilege('authenticated','public.encrypt_ai_api_key(text)','EXECUTE')
    or has_function_privilege('authenticated','public.decrypt_ai_api_key(text)','EXECUTE')
    or has_function_privilege('anon','public.decrypt_ai_api_key(text)','EXECUTE') then
    raise exception 'Client role can execute encryption RPCs';
  end if;
  if not has_function_privilege('service_role','public.decrypt_ai_api_key(text)','EXECUTE') then
    raise exception 'Server role cannot decrypt';
  end if;
end $$;
rollback;
select 'ai_key_encryption_tests_passed' as result;
