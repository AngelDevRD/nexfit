-- Borrado de cuenta (requisito de Google Play, docs/AUDITORIA_2026-09-04.md
-- Fase 0 item 5). NO aplicada todavia -- pendiente de que el usuario la
-- corra (ver supabase/migrations, aplicar con el CLI o el MCP de Supabase).
--
-- SECURITY DEFINER acotada a auth.uid(): un usuario autenticado solo puede
-- borrar su propia cuenta, nunca la de otro. Borra directamente de
-- auth.users -- todas las tablas nexfit_* referencian auth.users(id) con
-- "on delete cascade" (ver 20260904_0001_nexfit_schema.sql), asi que esa
-- unica sentencia se lleva en cascada perfil, rutinas, sesiones, series,
-- objetivos, check-ins, nutricion y retos del usuario.
create or replace function public.nexfit_delete_own_account()
returns void
language plpgsql security definer set search_path to 'public'
as $function$
begin
  delete from auth.users where id = auth.uid();
end;
$function$;

grant execute on function public.nexfit_delete_own_account() to authenticated;
