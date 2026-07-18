-- Option 1 migration: add Excel-style definitions and archive legacy defaults.
-- This preserves all grades and does NOT delete data.

-- 1) Add Excel-style definitions (only if missing)
insert into public.grade_definitions (course_subject_id, quarter_id, name, category, sort_order)
select cs.id, q.id, v.name, v.category, v.sort_order
from public.course_subjects cs
cross join public.quarters q
cross join (values
  ('Lecciones 1','INDIVIDUAL',1),
  ('Lecciones 2','INDIVIDUAL',2),
  ('Pruebas 1','INDIVIDUAL',3),
  ('Pruebas 2','INDIVIDUAL',4),
  ('Tareas 1','INDIVIDUAL',5),
  ('Tareas 2','INDIVIDUAL',6),
  ('Proyectos 1','INDIVIDUAL',7),
  ('Proyectos 2','INDIVIDUAL',8),
  ('Proyectos 1','GRUPAL',9),
  ('Proyectos 2','GRUPAL',10),
  ('Exposiciones 1','GRUPAL',11),
  ('Exposiciones 2','GRUPAL',12),
  ('Talleres 1','GRUPAL',13),
  ('Talleres 2','GRUPAL',14),
  ('Productos 1','GRUPAL',15),
  ('Productos 2','GRUPAL',16),
  ('Refuerzo Pedagogico','REFUERZO',17),
  ('Proyecto Interdisciplinario','SUMATIVA',18),
  ('Examen del Trimestre','SUMATIVA',19)
) as v(name, category, sort_order)
where not exists (
  select 1
  from public.grade_definitions gd
  where gd.course_subject_id = cs.id
    and gd.quarter_id = q.id
    and gd.name = v.name
    and gd.category = v.category
);

-- 2) Rename legacy refuerzo / sumativa if they exist
update public.grade_definitions
set name = 'Refuerzo Pedagogico'
where category = 'REFUERZO' and name = 'Refuerzo';

update public.grade_definitions
set name = 'Proyecto Interdisciplinario'
where category = 'SUMATIVA' and name = 'Proyecto';

update public.grade_definitions
set name = 'Examen del Trimestre'
where category = 'SUMATIVA' and name = 'Examen';

-- 3) Archive legacy default insumos to avoid extra columns
-- Only archive if new Excel-style definitions already exist for that course_subject + quarter.
update public.grade_definitions gd
set category = 'LEGACY'
where gd.category in ('INDIVIDUAL','GRUPAL')
  and gd.name in ('Insumo 1','Insumo 2','Insumo 3','Insumo 4')
  and exists (
    select 1 from public.grade_definitions gx
    where gx.course_subject_id = gd.course_subject_id
      and gx.quarter_id = gd.quarter_id
      and gx.name = 'Lecciones 1'
      and gx.category = 'INDIVIDUAL'
  );
