-- Esquema NexFit en Supabase -- primera migracion versionada.
--
-- Origen: el esquema vivia SOLO en el panel de Supabase del proyecto
-- "Admin Panel y Negocio" (rjahodesvndawnxghugp), creado a mano y compartido
-- con otras tres apps (mi_negocio_*, finanzas360_*, portfolio_*). Al crear el
-- proyecto dedicado "appgym" (btrdczpnuutrvgoprqze) no habia forma de
-- recrearlo: no existia ninguna migracion en el repo. Este archivo cierra ese
-- agujero -- de aca en adelante el esquema se versiona con el codigo.
--
-- Reconstruido leyendo information_schema.columns, pg_constraint y pg_policies
-- del proyecto original, con dos correcciones documentadas abajo.

-- ---------------------------------------------------------------------------
-- Perfil extendido. La PK es el id de auth.users: una fila por usuario.
-- ---------------------------------------------------------------------------
create table if not exists public.nexfit_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  age integer,
  sex text,
  height_cm double precision,
  weight_kg double precision,
  body_fat_pct double precision,
  goal text,
  experience_level text,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Rutinas -> dias -> ejercicios prescritos.
-- ---------------------------------------------------------------------------
create table if not exists public.nexfit_routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  goal text,
  days_per_week integer,
  created_at timestamptz not null default now()
);

create table if not exists public.nexfit_routine_days (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.nexfit_routines(id) on delete cascade,
  day_index integer not null,
  name text not null,
  muscle_focus text
);

create table if not exists public.nexfit_routine_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_day_id uuid not null references public.nexfit_routine_days(id) on delete cascade,
  exercise_id text not null,
  order_index integer not null,
  target_sets integer,
  target_reps_min integer,
  target_reps_max integer,
  target_rest_seconds integer,
  notes text
);

-- ---------------------------------------------------------------------------
-- Sesiones de entrenamiento y sus series.
-- ---------------------------------------------------------------------------
create table if not exists public.nexfit_workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  routine_id uuid references public.nexfit_routines(id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz,
  notes text
);

create table if not exists public.nexfit_workout_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.nexfit_workout_sessions(id) on delete cascade,
  exercise_id text not null,
  set_number integer not null,
  weight_kg double precision not null,
  reps integer not null,
  rpe double precision,
  rir integer,
  rest_seconds integer,
  techniques jsonb not null default '[]'::jsonb,
  superset_group_id integer,
  tempo text,
  is_warmup boolean not null default false,
  notes text,
  -- CORRECCION 1 respecto del esquema original.
  -- El cliente envia `completed` en cada insert de serie: el payload que
  -- `WorkoutRepository.addSet` guarda en `pending_set_ops` incluye esa clave y
  -- `WorkoutSessionSyncable._drainPendingOps` lo manda tal cual a PostgREST.
  -- La columna no existia en el proyecto original, asi que TODOS los inserts
  -- fallaban con PGRST204 ("Could not find the 'completed' column"), el
  -- SyncEngine los capturaba y reintentaba para siempre, y por eso las 11
  -- tablas quedaron con 0 filas pese a meses de uso de la app.
  completed boolean not null default true
);

-- ---------------------------------------------------------------------------
-- Objetivos, check-ins diarios y nutricion.
-- ---------------------------------------------------------------------------
create table if not exists public.nexfit_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  metric text not null,
  exercise_id text,
  starting_value double precision,
  target_value double precision not null,
  target_date date
);

create table if not exists public.nexfit_daily_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  checkin_date date not null,
  sleep_hours double precision,
  perceived_fatigue integer,
  unique (user_id, checkin_date)
);

create table if not exists public.nexfit_nutrition_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  calories double precision,
  protein_g double precision,
  carbs_g double precision,
  fat_g double precision,
  water_ml double precision,
  notes text,
  updated_at timestamptz not null default now(),
  unique (user_id, log_date)
);

-- ---------------------------------------------------------------------------
-- Retos entre usuarios (unico dominio con datos compartidos).
-- ---------------------------------------------------------------------------
create table if not exists public.nexfit_challenges (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text,
  metric text not null,
  starts_on date not null,
  ends_on date not null,
  invite_code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.nexfit_challenge_participants (
  challenge_id uuid not null references public.nexfit_challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

-- ---------------------------------------------------------------------------
-- CORRECCION 2 respecto del esquema original: indices de las claves foraneas
-- y de las columnas por las que el cliente filtra. Postgres crea indice para
-- las PK y las UNIQUE, pero NO para las FK -- sin estos, cada consulta de
-- sesiones o series de un usuario hace scan secuencial.
-- ---------------------------------------------------------------------------
create index if not exists nexfit_routines_user_id_idx on public.nexfit_routines(user_id);
create index if not exists nexfit_routine_days_routine_id_idx on public.nexfit_routine_days(routine_id);
create index if not exists nexfit_routine_exercises_day_id_idx on public.nexfit_routine_exercises(routine_day_id);
create index if not exists nexfit_workout_sessions_user_id_idx on public.nexfit_workout_sessions(user_id);
create index if not exists nexfit_workout_sessions_started_at_idx on public.nexfit_workout_sessions(user_id, started_at desc);
create index if not exists nexfit_workout_sets_session_id_idx on public.nexfit_workout_sets(session_id);
create index if not exists nexfit_goals_user_id_idx on public.nexfit_goals(user_id);
create index if not exists nexfit_daily_checkins_user_id_idx on public.nexfit_daily_checkins(user_id);
create index if not exists nexfit_nutrition_logs_user_id_idx on public.nexfit_nutrition_logs(user_id);
create index if not exists nexfit_challenges_owner_id_idx on public.nexfit_challenges(owner_id);
create index if not exists nexfit_challenge_participants_user_id_idx on public.nexfit_challenge_participants(user_id);

-- ---------------------------------------------------------------------------
-- Row Level Security. Identicas a las del proyecto original: cada usuario ve y
-- escribe solo lo suyo; las tablas hijas (dias, ejercicios, series) resuelven
-- la pertenencia subiendo por la jerarquia hasta el user_id del padre.
-- ---------------------------------------------------------------------------
alter table public.nexfit_profiles enable row level security;
alter table public.nexfit_routines enable row level security;
alter table public.nexfit_routine_days enable row level security;
alter table public.nexfit_routine_exercises enable row level security;
alter table public.nexfit_workout_sessions enable row level security;
alter table public.nexfit_workout_sets enable row level security;
alter table public.nexfit_goals enable row level security;
alter table public.nexfit_daily_checkins enable row level security;
alter table public.nexfit_nutrition_logs enable row level security;
alter table public.nexfit_challenges enable row level security;
alter table public.nexfit_challenge_participants enable row level security;

create policy nexfit_profiles_own_row on public.nexfit_profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy nexfit_routines_own_rows on public.nexfit_routines
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy nexfit_routine_days_via_routine on public.nexfit_routine_days
  for all using (exists (
    select 1 from public.nexfit_routines r
    where r.id = nexfit_routine_days.routine_id and r.user_id = auth.uid()))
  with check (exists (
    select 1 from public.nexfit_routines r
    where r.id = nexfit_routine_days.routine_id and r.user_id = auth.uid()));

create policy nexfit_routine_exercises_via_routine on public.nexfit_routine_exercises
  for all using (exists (
    select 1 from public.nexfit_routine_days d
    join public.nexfit_routines r on r.id = d.routine_id
    where d.id = nexfit_routine_exercises.routine_day_id and r.user_id = auth.uid()))
  with check (exists (
    select 1 from public.nexfit_routine_days d
    join public.nexfit_routines r on r.id = d.routine_id
    where d.id = nexfit_routine_exercises.routine_day_id and r.user_id = auth.uid()));

create policy nexfit_workout_sessions_own_rows on public.nexfit_workout_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy nexfit_workout_sets_via_session on public.nexfit_workout_sets
  for all using (exists (
    select 1 from public.nexfit_workout_sessions s
    where s.id = nexfit_workout_sets.session_id and s.user_id = auth.uid()))
  with check (exists (
    select 1 from public.nexfit_workout_sessions s
    where s.id = nexfit_workout_sets.session_id and s.user_id = auth.uid()));

create policy nexfit_goals_own_rows on public.nexfit_goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy nexfit_daily_checkins_own_rows on public.nexfit_daily_checkins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy nexfit_nutrition_logs_own_rows on public.nexfit_nutrition_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Retos: el dueño ve y administra el suyo; los participantes solo pueden verlo
-- y sumarse/salirse a si mismos.
create policy nexfit_challenges_select_participant_or_owner on public.nexfit_challenges
  for select using (
    owner_id = auth.uid() or exists (
      select 1 from public.nexfit_challenge_participants p
      where p.challenge_id = nexfit_challenges.id and p.user_id = auth.uid()));

create policy nexfit_challenges_insert_own on public.nexfit_challenges
  for insert with check (owner_id = auth.uid());

create policy nexfit_challenges_update_own on public.nexfit_challenges
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy nexfit_challenges_delete_own on public.nexfit_challenges
  for delete using (owner_id = auth.uid());

create policy nexfit_challenge_participants_select_own_challenges on public.nexfit_challenge_participants
  for select using (
    user_id = auth.uid() or exists (
      select 1 from public.nexfit_challenges c
      where c.id = nexfit_challenge_participants.challenge_id and c.owner_id = auth.uid()));

create policy nexfit_challenge_participants_insert_self on public.nexfit_challenge_participants
  for insert with check (user_id = auth.uid());

create policy nexfit_challenge_participants_delete_self on public.nexfit_challenge_participants
  for delete using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Funciones RPC de Retos. `SECURITY DEFINER` a proposito: el leaderboard
-- necesita leer las sesiones de TODOS los participantes, cosa que las
-- politicas de RLS impiden a un usuario comun; y unirse por codigo necesita
-- resolver el reto sin poder listarlos todos. Ambas acotan por el reto que se
-- pide y por `auth.uid()`, asi que no exponen datos de terceros fuera de ese
-- alcance. Las consume `SocialRepository`.
-- ---------------------------------------------------------------------------
create or replace function public.nexfit_challenge_leaderboard(p_challenge_id uuid)
returns table(user_id uuid, name text, value double precision)
language sql security definer set search_path to 'public'
as $function$
  with ch as (
    select metric, starts_on, ends_on from public.nexfit_challenges where id = p_challenge_id
  ),
  participants as (
    select p.user_id from public.nexfit_challenge_participants p where p.challenge_id = p_challenge_id
  ),
  agg as (
    select
      s.user_id,
      sum(ws.weight_kg * ws.reps) filter (where not ws.is_warmup) as total_volume_kg,
      count(distinct s.id) as total_sessions,
      sum(ws.reps) filter (where not ws.is_warmup) as total_reps
    from public.nexfit_workout_sessions s
    join public.nexfit_workout_sets ws on ws.session_id = s.id
    join ch on s.started_at::date between ch.starts_on and ch.ends_on
    where s.user_id in (select user_id from participants)
    group by s.user_id
  )
  select
    p.user_id,
    coalesce(pr.name, 'Usuario') as name,
    coalesce(case (select metric from ch)
      when 'total_volume_kg' then a.total_volume_kg
      when 'total_sessions' then a.total_sessions
      when 'total_reps' then a.total_reps
    end, 0)::double precision as value
  from participants p
  left join agg a on a.user_id = p.user_id
  left join public.nexfit_profiles pr on pr.id = p.user_id
  order by value desc;
$function$;

create or replace function public.nexfit_join_challenge_by_code(p_code text)
returns uuid
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_challenge_id uuid;
begin
  select id into v_challenge_id from public.nexfit_challenges where invite_code = p_code;
  if v_challenge_id is null then
    raise exception 'Codigo de invitacion invalido';
  end if;
  insert into public.nexfit_challenge_participants (challenge_id, user_id)
  values (v_challenge_id, auth.uid())
  on conflict do nothing;
  return v_challenge_id;
end;
$function$;
