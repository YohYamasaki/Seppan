-- Enforce server-side expiry on pending partnerships.
--
-- Previously, pending partnerships had a 30-minute expiry enforced only
-- on the client side. A malicious or modified client could call
-- joinPartnership() after the client-side timer expired, joining an
-- invite that should no longer be valid.
--
-- This migration tightens the RLS policies so that:
--   * The "join pending partnership" UPDATE is only allowed within
--     30 minutes of the partnership's creation.
--   * The "find pending partnership by ID" SELECT policy is scoped the
--     same way, so expired invites are effectively invisible to the
--     would-be joiner as well.

-- Drop the old permissive policies that lacked the age check.
DROP POLICY IF EXISTS "Anyone can find pending partnership by invite code"
  ON public.partnerships;
DROP POLICY IF EXISTS "Anyone can join pending partnership"
  ON public.partnerships;
DROP POLICY IF EXISTS "Users can join pending partnerships"
  ON public.partnerships;

-- Replace: pending partnerships are only discoverable within the 30-min
-- window. After that, partnership rows remain in the database but are
-- invisible to non-members.
CREATE POLICY "Anyone can find non-expired pending partnership"
  ON public.partnerships
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    status = 'pending'
    AND created_at > (now() - interval '30 minutes')
  );

-- Replace: joining is only allowed within the 30-min window, and only
-- to set user2_id to the current authenticated user (moving status to
-- 'active'). The age check prevents bypassing the client-side timer.
CREATE POLICY "Anyone can join non-expired pending partnership"
  ON public.partnerships
  AS PERMISSIVE
  FOR UPDATE
  TO authenticated
  USING (
    status = 'pending'
    AND user2_id IS NULL
    AND created_at > (now() - interval '30 minutes')
  )
  WITH CHECK (
    status = 'active'
    AND user2_id = auth.uid()
  );
