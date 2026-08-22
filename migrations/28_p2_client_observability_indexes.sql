-- Coverage for the auth.users foreign key and per-user rate-limit lookup.
CREATE INDEX IF NOT EXISTS idx_client_error_events_user_received
  ON public.client_error_events (user_id, received_at DESC);
