/* STUDENT ALERTS */
create table if not exists public.student_alerts (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references public.students(id) on delete cascade not null,
  course_id uuid references public.courses(id) on delete cascade not null,
  quarter_id uuid references public.quarters(id) on delete cascade not null,
  alert_type text not null check (alert_type in ('INDISCIPLINA', 'APROVECHAMIENTO', 'FALTA', 'FUGA', 'ATRASO', 'USO_CELULAR', 'ACOSO', 'OTRA')),
  severity text not null check (severity in ('LEVE', 'GRAVE', 'MUY_GRAVE')),
  description text not null,
  date_occurred timestamp with time zone not null,
  reported_by uuid references public.profiles(id) on delete set null,
  status text not null default 'PENDIENTE' check (status in ('PENDIENTE', 'EN_REVISION', 'CONVOCADO', 'RESUELTO', 'ARCHIVADO')),
  dece_notes text,
  resolution text,
  whatsapp_sent_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

/* RLS Policies */
alter table public.student_alerts enable row level security;

drop policy if exists "Enable read access for all users" on public.student_alerts;
create policy "Enable read access for all users" on public.student_alerts for select using (true);

drop policy if exists "Enable write for authenticated users" on public.student_alerts;
create policy "Enable write for authenticated users" on public.student_alerts for all using (auth.role() = 'authenticated');

/* Indexes */
create index if not exists idx_student_alerts_student_id on public.student_alerts(student_id);
create index if not exists idx_student_alerts_course_id on public.student_alerts(course_id);
create index if not exists idx_student_alerts_status on public.student_alerts(status);
create index if not exists idx_student_alerts_alert_type on public.student_alerts(alert_type);
create index if not exists idx_student_alerts_date_occurred on public.student_alerts(date_occurred);


