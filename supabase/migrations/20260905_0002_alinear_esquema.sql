-- Alinea el esquema remoto con el local (Drift schemaVersion 11).
--
-- Contexto (docs/AUDITORIA_2026-09-04.md, hallazgo A5): el esquema de
-- 20260904_0001 es un SUBCONJUNTO del local. Las columnas que faltan no
-- rompen el sync -- PostgREST simplemente nunca las recibe, porque el
-- cliente tampoco las manda -- pero significan que el "backup en la nube"
-- pierde datos en silencio: el nombre del entrenamiento, el dia de rutina
-- que se entreno, las notas y el orden por ejercicio, y todos los objetivos
-- avanzados de los ejercicios de una rutina.
--
-- TODAS las sentencias de este archivo son ADITIVAS e IDEMPOTENTES: no
-- borran, no renombran y no cambian ningun tipo existente. Se puede aplicar
-- sobre la base con datos sin riesgo de perdida.

-- ---------------------------------------------------------------------------
-- Sesiones de entrenamiento.
-- ---------------------------------------------------------------------------
-- `title`: nombre del entrenamiento (WorkoutSessions.title). Lo trae el
-- export de Hevy y lo escribe `StartWorkoutScreen` con el nombre del dia de
-- la rutina.
alter table public.nexfit_workout_sessions
  add column if not exists title text;

-- `updated_at`: el local ya lleva `updatedAt` en cada raiz de agregado; sin
-- el equivalente remoto no hay forma de resolver conflictos el dia que se
-- implemente `pull` (ADR-005 / hallazgo A6).
alter table public.nexfit_workout_sessions
  add column if not exists updated_at timestamptz not null default now();

-- `routine_day_id`: que dia de la rutina se entreno (WorkoutSessions.
-- routineDayId, esquema local v9).
--
-- ATENCION -- esta columna NO se puede poblar todavia, y es a proposito que
-- quede vacia hasta que se resuelva lo de abajo: el id local de un dia de
-- rutina es un int autoincremental, y aca hace falta el uuid remoto. La
-- tabla local `RoutineDays` NO tiene columna `serverId` (a diferencia de
-- `Routines` y `WorkoutSessions`), asi que hoy no existe ninguna forma de
-- traducir uno en otro. Antes de que `WorkoutSessionSyncable` mande este
-- campo hay que:
--   1. agregar `serverId` a `RoutineDays` en lib/core/local/database.dart
--      (con su migracion de Drift),
--   2. hacer que `RoutineSyncable` lo complete al subir cada dia,
--   3. recien entonces resolver `routineDayId -> serverId` en
--      `WorkoutSessionSyncable._pushStart`, igual que ya hace con la rutina.
-- Se crea la columna ahora para que el esquema quede completo y la migracion
-- no haya que repetirla, pero el cliente la seguira ignorando hasta el paso 3.
alter table public.nexfit_workout_sessions
  add column if not exists routine_day_id uuid
    references public.nexfit_routine_days(id) on delete set null;

-- ---------------------------------------------------------------------------
-- Series. `exercise_notes` y `exercise_order` son datos a nivel EJERCICIO
-- dentro de la sesion, duplicados en cada fila de ese ejercicio (mismo patron
-- que `rest_seconds`); ver el comentario de `WorkoutSets` en database.dart.
-- ---------------------------------------------------------------------------
alter table public.nexfit_workout_sets
  add column if not exists exercise_notes text,
  add column if not exists exercise_order integer;

-- ---------------------------------------------------------------------------
-- Ejercicios prescritos en una rutina: 5 columnas que el constructor de
-- rutinas ya escribe en local y que hoy no viajan a ningun lado.
-- ---------------------------------------------------------------------------
alter table public.nexfit_routine_exercises
  add column if not exists target_weight_kg double precision,
  add column if not exists set_type text not null default 'normal',
  add column if not exists tempo text,
  add column if not exists target_rpe double precision,
  add column if not exists target_rir integer;

-- ---------------------------------------------------------------------------
-- Indice faltante detectado por el linter de Supabase (0001_unindexed_
-- foreign_keys): `nexfit_workout_sessions.routine_id` es FK sin indice.
-- ---------------------------------------------------------------------------
create index if not exists nexfit_workout_sessions_routine_id_idx
  on public.nexfit_workout_sessions(routine_id);

create index if not exists nexfit_workout_sessions_routine_day_id_idx
  on public.nexfit_workout_sessions(routine_day_id);

-- ---------------------------------------------------------------------------
-- Ejercicios propios del usuario (hallazgo A15).
--
-- Hoy los ejercicios creados desde la app (ExerciseRepository, ids desde
-- 1.000.000, slug `custom-<id>`) existen SOLO en la base local: no hay
-- `ExerciseSyncable`, asi que reinstalar la app los pierde -- y con ellos
-- deja huerfanas las series que los referencian.
--
-- El catalogo BASE no va aca a proposito: es estatico, identico para todos
-- los usuarios, y vive en assets/data/exercises.json. Replicarlo seria pagar
-- lecturas y egress por datos que nunca cambian (ver seccion 13 del prompt
-- maestro).
-- ---------------------------------------------------------------------------
create table if not exists public.nexfit_custom_exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  -- `slug` local (`custom-<id>`): identidad estable del ejercicio para el
  -- usuario, y lo que permite un upsert idempotente desde el cliente.
  slug text not null,
  name text not null,
  muscle_group text not null,
  difficulty text not null,
  -- Resto de campos (musculos, equipo, instrucciones...) como JSON, igual
  -- que `Exercises.detailJson` en local.
  detail_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id, slug)
);

create index if not exists nexfit_custom_exercises_user_id_idx
  on public.nexfit_custom_exercises(user_id);

alter table public.nexfit_custom_exercises enable row level security;

-- `(select auth.uid())` y no `auth.uid()` a secas: envuelto en un subselect
-- Postgres lo evalua UNA vez (InitPlan) en vez de por fila. Ver la migracion
-- 0003, que aplica lo mismo a las 16 politicas ya existentes.
drop policy if exists nexfit_custom_exercises_own_rows
  on public.nexfit_custom_exercises;
create policy nexfit_custom_exercises_own_rows on public.nexfit_custom_exercises
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
