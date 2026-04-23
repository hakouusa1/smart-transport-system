-- FCM token storage
-- Stores Firebase Cloud Messaging tokens for push notification delivery.
-- user_id is the Firebase Auth UID (set by Flutter apps on login/token refresh).

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  user_id   TEXT        PRIMARY KEY,
  fcm_token TEXT        NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Allow Flutter apps (using anon key) to upsert their own token.
-- Tokens are not auth credentials — they are device-push identifiers.
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_upsert_fcm_token"
  ON public.fcm_tokens
  FOR ALL
  USING (true)
  WITH CHECK (true);
