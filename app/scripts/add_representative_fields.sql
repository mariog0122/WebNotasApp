-- Full sync for students columns used by the app
alter table public.students
  add column if not exists student_cedula text,
  add column if not exists student_birthdate date,
  add column if not exists student_phone text,
  add column if not exists student_address text,
  add column if not exists representative_name text,
  add column if not exists representative_cedula text,
  add column if not exists representative_phone text,
  add column if not exists representative_alt_phone text,
  add column if not exists student_photo_url text,
  add column if not exists representative_photo_url text;
