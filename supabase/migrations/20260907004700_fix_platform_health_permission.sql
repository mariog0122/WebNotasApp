-- The monitor is protected by is_platform_admin() inside the function.
-- This restores access for the authenticated client role only.
REVOKE ALL ON FUNCTION public.get_platform_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_platform_health() TO authenticated;
