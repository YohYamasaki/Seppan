-- Prevent a user from pairing with themselves.
-- The CHECK allows NULL in either column (pending partnerships have user2_id = NULL).
ALTER TABLE partnerships
  ADD CONSTRAINT no_self_pair
  CHECK (user1_id IS NULL OR user2_id IS NULL OR user1_id <> user2_id);
