-- GoTrue deletes auth.users with the service role. The public identity row must
-- follow that lifecycle or the Auth deletion fails with SQLSTATE 23503.
alter table public.profiles
  drop constraint if exists profiles_id_fkey;

alter table public.profiles
  add constraint profiles_id_fkey
  foreign key (id)
  references auth.users (id)
  on delete cascade;

