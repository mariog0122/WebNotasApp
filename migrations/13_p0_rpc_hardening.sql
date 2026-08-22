-- P0 follow-up: cierra el alta heredada y evita SECURITY DEFINER innecesario.
BEGIN;

REVOKE EXECUTE ON FUNCTION public.invite_teacher_by_email(text) FROM authenticated;

ALTER FUNCTION public.get_academic_years_list() SECURITY INVOKER;
ALTER FUNCTION public.get_current_academic_year() SECURITY INVOKER;
ALTER FUNCTION public.get_my_role() SECURITY INVOKER;

COMMIT;
