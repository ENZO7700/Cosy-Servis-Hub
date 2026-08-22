-- Trigger-only helpers: switch to SECURITY INVOKER, revoke all EXECUTE
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public'
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_tracking_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public'
AS $function$
BEGIN
  NEW.tracking_id = 'BUG-' || LPAD(nextval('public.bug_tracking_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.generate_tracking_id() FROM PUBLIC, anon, authenticated;

-- Auth user trigger: definer required, no API grants
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- has_role: definer needed for RLS recursion, must be callable by authenticated (used in policies),
-- but not by anon or general public.
REVOKE ALL ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;

-- get_team_members: definer needed to join across tables; authenticated only.
REVOKE ALL ON FUNCTION public.get_team_members() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_members() TO authenticated;
