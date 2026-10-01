-- ==============================================================================
-- LOGREVA — CAPA DE INTELIGENCIA DEL APRENDIZAJE (FASE 1: LEARNING GRAPH & DIAGNÓSTICO)
-- Migración 100% aditiva sin impacto destructivo en calificaciones oficiales
-- ==============================================================================

-- 1. CATÁLOGO DE COMPETENCIAS CURRICULARES (VERSIONADO)
create table if not exists public.competencies (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade, -- null para catálogo estándar nacional
  code text not null,
  name text not null,
  description text,
  subject_area text not null,
  grade_level text not null,
  curriculum_version text not null default 'EC-2026.1',
  status text not null default 'active' check (status in ('active', 'draft', 'archived')),
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_competencies_subject_grade on public.competencies(subject_area, grade_level);
create index if not exists idx_competencies_code on public.competencies(code);
create index if not exists idx_competencies_school_id on public.competencies(school_id);

-- 2. GRAFO DE DEPENDENCIAS Y PRERREQUISITOS (EDGES)
create table if not exists public.competency_edges (
  id uuid primary key default gen_random_uuid(),
  from_competency_id uuid not null references public.competencies(id) on delete cascade,
  to_competency_id uuid not null references public.competencies(id) on delete cascade,
  edge_type text not null default 'prerequisite' check (edge_type in ('prerequisite', 'co_requisite', 'extension')),
  weight numeric not null default 1.0 check (weight > 0 and weight <= 2.0),
  curriculum_version text not null default 'EC-2026.1',
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  constraint unique_competency_edge unique (from_competency_id, to_competency_id, edge_type)
);

create index if not exists idx_competency_edges_from on public.competency_edges(from_competency_id);
create index if not exists idx_competency_edges_to on public.competency_edges(to_competency_id);

-- 3. BANCO DE REACTIVOS DIAGNÓSTICOS
create table if not exists public.assessment_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade, -- null para banco global
  subject_area text not null,
  grade_level text not null,
  item_type text not null default 'multiple_choice' check (item_type in ('multiple_choice', 'open_short', 'rubric')),
  stem text not null,
  options jsonb default '[]'::jsonb,
  correct_answer text not null,
  explanation text,
  hints jsonb default '[]'::jsonb,
  difficulty numeric not null default 0.5 check (difficulty >= 0 and difficulty <= 1),
  status text not null default 'active' check (status in ('active', 'draft', 'retired')),
  version text not null default '1.0',
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_assessment_items_subject_grade on public.assessment_items(subject_area, grade_level);
create index if not exists idx_assessment_items_school_id on public.assessment_items(school_id);

-- 4. RELACIÓN ÍTEM - COMPETENCIAS (N:M CON PESOS)
create table if not exists public.assessment_item_competencies (
  id uuid primary key default gen_random_uuid(),
  assessment_item_id uuid not null references public.assessment_items(id) on delete cascade,
  competency_id uuid not null references public.competencies(id) on delete cascade,
  weight numeric not null default 1.0 check (weight > 0 and weight <= 1.0),
  is_primary boolean not null default true,
  created_at timestamptz default now(),
  constraint unique_item_competency unique (assessment_item_id, competency_id)
);

create index if not exists idx_item_competencies_item on public.assessment_item_competencies(assessment_item_id);
create index if not exists idx_item_competencies_comp on public.assessment_item_competencies(competency_id);

-- 5. REGISTRO ATÓMICO DE EVIDENCIAS DE APRENDIZAJE
create table if not exists public.student_evidence (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  assessment_item_id uuid references public.assessment_items(id) on delete set null,
  competency_id uuid not null references public.competencies(id) on delete cascade,
  source text not null default 'diagnostic' check (source in ('diagnostic', 'practice', 'quiz', 'observation', 'tutor')),
  score numeric not null check (score >= 0 and score <= 1),
  raw_response text,
  rubric_result jsonb default '{}'::jsonb,
  confidence numeric not null default 0.8 check (confidence >= 0 and confidence <= 1),
  model_version text not null default 'v1.0',
  occurred_at timestamptz default now(),
  created_at timestamptz default now()
);

create index if not exists idx_student_evidence_student_comp on public.student_evidence(school_id, student_id, competency_id);
create index if not exists idx_student_evidence_occurred on public.student_evidence(occurred_at desc);

-- 6. ESTADO DE DOMINIO CONTINUO (MASTERY STATE)
create table if not exists public.mastery_state (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  competency_id uuid not null references public.competencies(id) on delete cascade,
  mastery_score numeric not null default 0 check (mastery_score >= 0 and mastery_score <= 1),
  confidence numeric not null default 0.5 check (confidence >= 0 and confidence <= 1),
  attempt_count integer not null default 1 check (attempt_count >= 0),
  state text not null default 'NOT_EVIDENCED' check (state in ('NOT_EVIDENCED', 'DEVELOPING', 'COMPETENT', 'MASTERED', 'AT_RISK_OF_FORGETTING')),
  last_evidence_at timestamptz default now(),
  model_version text not null default 'v1.0',
  updated_at timestamptz default now(),
  constraint unique_student_competency_mastery unique (school_id, student_id, competency_id)
);

create index if not exists idx_mastery_state_student on public.mastery_state(school_id, student_id);
create index if not exists idx_mastery_state_comp on public.mastery_state(school_id, competency_id);

-- 7. BRECHAS DE APRENDIZAJE DETECTADAS (LEARNING GAPS)
create table if not exists public.learning_gaps (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid references public.students(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  competency_id uuid not null references public.competencies(id) on delete cascade,
  cause_competency_id uuid references public.competencies(id) on delete set null,
  severity text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  priority numeric not null default 1.0,
  status text not null default 'open' check (status in ('open', 'in_recovery', 'resolved', 'dismissed')),
  confidence numeric not null default 0.75 check (confidence >= 0 and confidence <= 1),
  opened_at timestamptz default now(),
  closed_at timestamptz,
  metadata jsonb default '{}'::jsonb
);

create index if not exists idx_learning_gaps_school_course on public.learning_gaps(school_id, course_id, status);
create index if not exists idx_learning_gaps_student on public.learning_gaps(school_id, student_id, status);

-- 8. CATÁLOGO DE MICROINTERVENCIONES PEDAGÓGICAS
create table if not exists public.interventions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade, -- null para catálogo estándar
  competency_id uuid not null references public.competencies(id) on delete cascade,
  strategy text not null default 'micro_lesson' check (strategy in ('micro_lesson', 'worked_example', 'guided_practice', 'peer_tutoring', 'spaced_retrieval')),
  title text not null,
  description text not null,
  duration_minutes integer not null default 15 check (duration_minutes > 0 and duration_minutes <= 60),
  resource_payload jsonb default '{}'::jsonb,
  version text not null default '1.0',
  status text not null default 'active' check (status in ('active', 'draft', 'archived')),
  created_at timestamptz default now()
);

create index if not exists idx_interventions_comp on public.interventions(competency_id);

-- 9. EJECUCIÓN Y SEGUIMIENTO DE INTERVENCIONES
create table if not exists public.intervention_runs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  intervention_id uuid not null references public.interventions(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid references public.courses(id) on delete set null,
  student_id uuid references public.students(id) on delete cascade,
  started_at timestamptz default now(),
  completed_at timestamptz,
  outcome text default 'in_progress' check (outcome in ('in_progress', 'completed', 'verified_mastery', 'needs_further_support', 'abandoned')),
  notes text,
  created_at timestamptz default now()
);

create index if not exists idx_intervention_runs_school_teacher on public.intervention_runs(school_id, teacher_id);
create index if not exists idx_intervention_runs_student on public.intervention_runs(school_id, student_id);

-- 10. TRAZABILIDAD Y TELEMETRÍA DE IA (SIN PII)
create table if not exists public.ai_traces (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  use_case text not null,
  provider text not null,
  model text not null,
  prompt_version text not null default '1.0',
  input_hash text,
  cost_estimate numeric default 0,
  latency_ms integer default 0,
  outcome text not null default 'success',
  safety_flags jsonb default '[]'::jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_ai_traces_school_usecase on public.ai_traces(school_id, use_case);

-- ==============================================================================
-- ACTIVACIÓN DE ROW LEVEL SECURITY (RLS) EN LAS 10 TABLAS
-- ==============================================================================
alter table public.competencies enable row level security;
alter table public.competency_edges enable row level security;
alter table public.assessment_items enable row level security;
alter table public.assessment_item_competencies enable row level security;
alter table public.student_evidence enable row level security;
alter table public.mastery_state enable row level security;
alter table public.learning_gaps enable row level security;
alter table public.interventions enable row level security;
alter table public.intervention_runs enable row level security;
alter table public.ai_traces enable row level security;

-- POLÍTICAS: Competencies (Lectura global o por tenant, escritura admin)
drop policy if exists competencies_select on public.competencies;
create policy competencies_select on public.competencies for select to authenticated
using (school_id is null or school_id = public.get_user_school_id() or public.is_platform_admin());

drop policy if exists competencies_manage on public.competencies;
create policy competencies_manage on public.competencies for all to authenticated
using (public.is_platform_admin() or (school_id = public.get_user_school_id() and public.has_tenant_permission('settings.manage')));

-- POLÍTICAS: Competency Edges
drop policy if exists competency_edges_select on public.competency_edges;
create policy competency_edges_select on public.competency_edges for select to authenticated using (true);

drop policy if exists competency_edges_manage on public.competency_edges;
create policy competency_edges_manage on public.competency_edges for all to authenticated
using (public.is_platform_admin());

-- POLÍTICAS: Assessment Items & Competencies
drop policy if exists assessment_items_select on public.assessment_items;
create policy assessment_items_select on public.assessment_items for select to authenticated
using (school_id is null or school_id = public.get_user_school_id() or public.is_platform_admin());

drop policy if exists assessment_item_competencies_select on public.assessment_item_competencies;
create policy assessment_item_competencies_select on public.assessment_item_competencies for select to authenticated using (true);

-- POLÍTICAS: Student Evidence (Solo tenant autorizado)
drop policy if exists student_evidence_select on public.student_evidence;
create policy student_evidence_select on public.student_evidence for select to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and public.can_access_student(student_id, 'students.read')
  )
);

drop policy if exists student_evidence_insert on public.student_evidence;
create policy student_evidence_insert on public.student_evidence for insert to authenticated
with check (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and public.can_access_student(student_id, 'grades.read')
  )
);

-- POLÍTICAS: Mastery State
drop policy if exists mastery_state_select on public.mastery_state;
create policy mastery_state_select on public.mastery_state for select to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and public.can_access_student(student_id, 'students.read')
  )
);

drop policy if exists mastery_state_manage on public.mastery_state;
create policy mastery_state_manage on public.mastery_state for all to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and public.has_tenant_permission('grades.update')
  )
);

-- POLÍTICAS: Learning Gaps
drop policy if exists learning_gaps_select on public.learning_gaps;
create policy learning_gaps_select on public.learning_gaps for select to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and (
      student_id is null or public.can_access_student(student_id, 'students.read')
    )
  )
);

drop policy if exists learning_gaps_manage on public.learning_gaps;
create policy learning_gaps_manage on public.learning_gaps for all to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and public.has_tenant_permission('grades.update')
  )
);

-- POLÍTICAS: Interventions
drop policy if exists interventions_select on public.interventions;
create policy interventions_select on public.interventions for select to authenticated
using (school_id is null or school_id = public.get_user_school_id() or public.is_platform_admin());

-- POLÍTICAS: Intervention Runs
drop policy if exists intervention_runs_select on public.intervention_runs;
create policy intervention_runs_select on public.intervention_runs for select to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and (teacher_id = auth.uid() or public.has_tenant_permission('reports.read'))
  )
);

drop policy if exists intervention_runs_manage on public.intervention_runs;
create policy intervention_runs_manage on public.intervention_runs for all to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and teacher_id = auth.uid()
  )
);

-- POLÍTICAS: AI Traces
drop policy if exists ai_traces_select on public.ai_traces;
create policy ai_traces_select on public.ai_traces for select to authenticated
using (
  public.is_platform_admin() or (
    school_id = public.get_user_school_id() and public.has_tenant_permission('settings.manage')
  )
);

drop policy if exists ai_traces_insert on public.ai_traces;
create policy ai_traces_insert on public.ai_traces for insert to authenticated
with check (
  school_id = public.get_user_school_id() or public.is_platform_admin()
);

-- ==============================================================================
-- SEMILLA BASE: COMPETENCIAS ESTÁNDAR Y PRERREQUISITOS (MATEMÁTICA Y LENGUAJE)
-- ==============================================================================
insert into public.competencies (id, school_id, code, name, description, subject_area, grade_level, curriculum_version)
values
  ('11111111-0000-0000-0000-000000000001', null, 'M.3.1.7', 'Operaciones con números naturales', 'Resolver multiplicaciones y divisiones exactas con números naturales de hasta 4 cifras.', 'Matemática', 'Media', 'EC-2026.1'),
  ('11111111-0000-0000-0000-000000000002', null, 'M.3.1.9', 'Fracciones y representaciones', 'Reconocer fracciones homogéneas y heterogéneas como partes de la unidad y operadores.', 'Matemática', 'Media', 'EC-2026.1'),
  ('11111111-0000-0000-0000-000000000003', null, 'M.3.1.33', 'Operaciones con fracciones', 'Resolver sumas y restas de fracciones con diferente denominador mediante mcm.', 'Matemática', 'Media', 'EC-2026.1'),
  ('11111111-0000-0000-0000-000000000004', null, 'M.3.1.37', 'Resolución de problemas fraccionarios', 'Aplicar fracciones en problemas de la vida cotidiana y contextos reales.', 'Matemática', 'Media', 'EC-2026.1'),
  ('22222222-0000-0000-0000-000000000001', null, 'LL.3.3.2', 'Comprensión literal y explícita', 'Comprender los contenidos implícitos y explícitos de textos narrativos e informativos.', 'Lengua y Literatura', 'Media', 'EC-2026.1'),
  ('22222222-0000-0000-0000-000000000002', null, 'LL.3.3.4', 'Inferencia y causa-efecto', 'Autorregular la comprensión mediante la lectura inferencial y relaciones de causa-efecto.', 'Lengua y Literatura', 'Media', 'EC-2026.1'),
  ('22222222-0000-0000-0000-000000000003', null, 'LL.3.3.8', 'Extracción de idea principal', 'Identificar la idea principal, ideas secundarias y síntesis global del texto.', 'Lengua y Literatura', 'Media', 'EC-2026.1')
on conflict do nothing;

-- Prerrequisitos de Matemática:
-- Operaciones básicas -> Fracciones -> Operaciones con fracciones -> Problemas cotidianos
insert into public.competency_edges (from_competency_id, to_competency_id, edge_type, weight)
values
  ('11111111-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000002', 'prerequisite', 1.0),
  ('11111111-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000003', 'prerequisite', 1.2),
  ('11111111-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000004', 'prerequisite', 1.5),
  ('22222222-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000002', 'prerequisite', 1.0),
  ('22222222-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000003', 'prerequisite', 1.3)
on conflict do nothing;

-- Semilla de Ítems Diagnósticos Validados
insert into public.assessment_items (id, school_id, subject_area, grade_level, item_type, stem, options, correct_answer, explanation, hints, difficulty)
values
  (
    '33333333-0000-0000-0000-000000000001',
    null,
    'Matemática',
    'Media',
    'multiple_choice',
    '¿Cuál es el resultado de sumar 1/2 + 1/4?',
    '[{"key": "A", "text": "2/6"}, {"key": "B", "text": "3/4"}, {"key": "C", "text": "2/4"}, {"key": "D", "text": "1/8"}]'::jsonb,
    'B',
    'Para sumar fracciones con distinto denominador encontramos el mcm de 2 y 4, que es 4. 1/2 equivale a 2/4. Luego 2/4 + 1/4 = 3/4.',
    '["Observa que los denominadores son diferentes (2 y 4).", "¿Cuántos cuartos equivalen a un medio?", "Convierte 1/2 en cuartos y súmale 1/4."]'::jsonb,
    0.45
  ),
  (
    '33333333-0000-0000-0000-000000000002',
    null,
    'Matemática',
    'Media',
    'multiple_choice',
    'Si una pizza se divide en 8 porciones iguales y Juan come 3 porciones y María 2, ¿qué fracción de pizza queda?',
    '[{"key": "A", "text": "5/8"}, {"key": "B", "text": "3/8"}, {"key": "C", "text": "1/2"}, {"key": "D", "text": "2/8"}]'::jsonb,
    'B',
    'Se consumieron 3/8 + 2/8 = 5/8. La pizza entera son 8/8. Restamos 8/8 - 5/8 = 3/8.',
    '["Primero calcula cuántas porciones comieron en total Juan y María.", "Resta esa cantidad del total de porciones de la pizza entera (8)."]'::jsonb,
    0.50
  ),
  (
    '33333333-0000-0000-0000-000000000003',
    null,
    'Lengua y Literatura',
    'Media',
    'multiple_choice',
    'Lee: \"El cielo se cubrió de densas nubes oscuras y un viento frío comenzó a sacudir los árboles. Los pájaros volaron apresurados a sus nidos.\" ¿Qué se puede inferir?',
    '[{"key": "A", "text": "Es de noche."}, {"key": "B", "text": "Se avecina una tormenta."}, {"key": "C", "text": "Es un día de verano soleado."}, {"key": "D", "text": "Los pájaros tienen hambre."}]'::jsonb,
    'B',
    'Las nubes oscuras, el viento frío y el comportamiento de los animales son indicios que permiten anticipar una tormenta.',
    '["¿Qué tipo de clima anuncian las nubes oscuras y el viento frío?", "¿Por qué los pájaros buscarían refugio de repente?"]'::jsonb,
    0.35
  )
on conflict do nothing;

-- Relacionar ítems con competencias
insert into public.assessment_item_competencies (assessment_item_id, competency_id, weight, is_primary)
values
  ('33333333-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000003', 1.0, true),
  ('33333333-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000004', 1.0, true),
  ('33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000002', 1.0, true)
on conflict do nothing;

-- Semilla de Microintervenciones Pedagógicas
insert into public.interventions (id, school_id, competency_id, strategy, title, description, duration_minutes, resource_payload)
values
  (
    '44444444-0000-0000-0000-000000000001',
    null,
    '11111111-0000-0000-0000-000000000003',
    'worked_example',
    'Modelado guiado: Suma de fracciones con tiras gráficas',
    'Microlección interactiva de 15 min utilizando representación concreta con barras de chocolate o tiras para unificar denominadores antes del cálculo formal.',
    15,
    '{"activity": "Representar 1/2 y 1/4 con rectángulos divididos", "checkpoint": "El estudiante explica por qué 1/2 equivale a 2/4"}'::jsonb
  ),
  (
    '44444444-0000-0000-0000-000000000002',
    null,
    '22222222-0000-0000-0000-000000000002',
    'guided_practice',
    'Cazadores de pistas: Deducción de causas en textos cortos',
    'Práctica guiada de 15 min donde los estudiantes subrayan con azul las pistas del texto y con verde la deducción lógica que no está escrita explícitamente.',
    15,
    '{"activity": "Lectura de 3 microtextos con deducciones situacionales", "checkpoint": "El estudiante justifica su respuesta citando al menos 1 indicio"}'::jsonb
  )
on conflict do nothing;
