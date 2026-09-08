-- Endurece RLS y las funciones RPC. Ver docs/AUDITORIA_2026-09-04.md,
-- hallazgos A7 (RPC ejecutables por `anon`) y A9 (16 politicas que
-- re-evaluan auth.uid() por fila).
--
-- NINGUNA politica cambia su LOGICA: los predicados son exactamente los
-- mismos que ya estan en produccion (verificados leyendo pg_policies), solo
-- se envuelve `auth.uid()` en un subselect. Quien ve que datos no cambia.
--
-- Por que el subselect: Postgres evalua `auth.uid()` una vez POR FILA cuando
-- aparece suelto en un predicado de RLS. Envuelto en `(select auth.uid())`
-- pasa a ser un InitPlan que se calcula una sola vez por consulta. Con un
-- historial importado de Hevy (miles de series) la diferencia es real.
-- Linter de Supabase: 0003_auth_rls_initplan.

-- ---------------------------------------------------------------------------
-- Politicas `for all` sobre la columna del dueño.
-- ---------------------------------------------------------------------------
alter policy nexfit_profiles_own_row on public.nexfit_profiles
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

alter policy nexfit_routines_own_rows on public.nexfit_routines
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter policy nexfit_workout_sessions_own_rows on public.nexfit_workout_sessions
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter policy nexfit_goals_own_rows on public.nexfit_goals
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter policy nexfit_daily_checkins_own_rows on public.nexfit_daily_checkins
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter policy nexfit_nutrition_logs_own_rows on public.nexfit_nutrition_logs
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Politicas de tablas hijas: resuelven la pertenencia subiendo por la
-- jerarquia. Misma estructura, mismo EXISTS, solo cambia el auth.uid().
-- ---------------------------------------------------------------------------
alter policy nexfit_routine_days_via_routine on public.nexfit_routine_days
  using (exists (
    select 1 from public.nexfit_routines r
    where r.id = nexfit_routine_days.routine_id
      and r.user_id = (select auth.uid())))
  with check (exists (
    select 1 from public.nexfit_routines r
    where r.id = nexfit_routine_days.routine_id
      and r.user_id = (select auth.uid())));

alter policy nexfit_routine_exercises_via_routine on public.nexfit_routine_exercises
  using (exists (
    select 1 from public.nexfit_routine_days d
    join public.nexfit_routines r on r.id = d.routine_id
    where d.id = nexfit_routine_exercises.routine_day_id
      and r.user_id = (select auth.uid())))
  with check (exists (
    select 1 from public.nexfit_routine_days d
    join public.nexfit_routines r on r.id = d.routine_id
    where d.id = nexfit_routine_exercises.routine_day_id
      and r.user_id = (select auth.uid())));

alter policy nexfit_workout_sets_via_session on public.nexfit_workout_sets
  using (exists (
    select 1 from public.nexfit_workout_sessions s
    where s.id = nexfit_workout_sets.session_id
      and s.user_id = (select auth.uid())))
  with check (exists (
    select 1 from public.nexfit_workout_sessions s
    where s.id = nexfit_workout_sets.session_id
      and s.user_id = (select auth.uid())));

-- ---------------------------------------------------------------------------
-- Retos. Ojo con la forma de cada politica: una de INSERT solo admite
-- `with check`, y una de SELECT/DELETE solo `using` -- pasarle la clausula
-- que no corresponde es un error de sintaxis, no un no-op.
-- ---------------------------------------------------------------------------
alter policy nexfit_challenges_select_participant_or_owner on public.nexfit_challenges
  using (
    owner_id = (select auth.uid()) or exists (
      select 1 from public.nexfit_challenge_participants p
      where p.challenge_id = nexfit_challenges.id
        and p.user_id = (select auth.uid())));

alter policy nexfit_challenges_insert_own on public.nexfit_challenges
  with check (owner_id = (select auth.uid()));

alter policy nexfit_challenges_update_own on public.nexfit_challenges
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

alter policy nexfit_challenges_delete_own on public.nexfit_challenges
  using (owner_id = (select auth.uid()));

alter policy nexfit_challenge_participants_select_own_challenges on public.nexfit_challenge_participants
  using (
    user_id = (select auth.uid()) or exists (
      select 1 from public.nexfit_challenges c
      where c.id = nexfit_challenge_participants.challenge_id
        and c.owner_id = (select auth.uid())));

alter policy nexfit_challenge_participants_insert_self on public.nexfit_challenge_participants
  with check (user_id = (select auth.uid()));

alter policy nexfit_challenge_participants_delete_self on public.nexfit_challenge_participants
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- A7 -- Las dos RPC son `SECURITY DEFINER` (necesario: el leaderboard tiene
-- que leer sesiones de OTROS usuarios, cosa que RLS le prohibe a un usuario
-- comun). Pero hoy las puede invocar el rol `anon`, es decir cualquiera con
-- la anon key -- que va dentro del APK y por lo tanto es publica.
-- Linter de Supabase: 0028_anon_security_definer_function_executable.
-- ---------------------------------------------------------------------------
revoke execute on function public.nexfit_challenge_leaderboard(uuid) from anon, public;
revoke execute on function public.nexfit_join_challenge_by_code(text) from anon, public;
grant execute on function public.nexfit_challenge_leaderboard(uuid) to authenticated;
grant execute on function public.nexfit_join_challenge_by_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- A7 (segunda mitad) -- Con lo de arriba hace falta estar autenticado, pero
-- CUALQUIER autenticado que adivine (o vea) un uuid de reto puede leer el
-- leaderboard completo: nombres y volumenes de gente con la que no comparte
-- nada. La funcion se acota a que quien llama sea participante o dueño de
-- ESE reto; si no lo es, devuelve cero filas.
--
-- Se mantiene en lenguaje `sql` y con la misma firma y semantica para los
-- llamadores legitimos (SocialRepository no cambia).
-- ---------------------------------------------------------------------------
create or replace function public.nexfit_challenge_leaderboard(p_challenge_id uuid)
returns table(user_id uuid, name text, value double precision)
language sql security definer set search_path to 'public'
as $function$
  with caller_allowed as (
    -- Participante del reto...
    select 1
    from public.nexfit_challenge_participants me
    where me.challenge_id = p_challenge_id
      and me.user_id = (select auth.uid())
    union all
    -- ...o su dueño (que puede no haberse sumado como participante).
    select 1
    from public.nexfit_challenges c
    where c.id = p_challenge_id
      and c.owner_id = (select auth.uid())
  ),
  ch as (
    select metric, starts_on, ends_on
    from public.nexfit_challenges
    where id = p_challenge_id
      and exists (select 1 from caller_allowed)
  ),
  participants as (
    select p.user_id
    from public.nexfit_challenge_participants p
    where p.challenge_id = p_challenge_id
      and exists (select 1 from caller_allowed)
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

revoke execute on function public.nexfit_challenge_leaderboard(uuid) from anon, public;
grant execute on function public.nexfit_challenge_leaderboard(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- A8 -- La proteccion contra contraseñas filtradas (HaveIBeenPwned) NO se
-- activa por SQL: es un ajuste del panel, en Authentication -> Sign In /
-- Providers -> Password -> "Prevent use of leaked passwords". Queda anotado
-- aca para que no se pierda; hay que hacerlo a mano.
-- ---------------------------------------------------------------------------
