-- Fix: Add authorization check to delete_user_data(target_user_id)
-- The parameterized version was SECURITY DEFINER with no auth.uid() check,
-- allowing any authenticated user to delete any other user's data.

CREATE OR REPLACE FUNCTION public.delete_user_data(target_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Authorization: only allow users to delete their own data
  IF target_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'unauthorized: cannot delete another user''s data';
  END IF;

  DELETE FROM expenses WHERE paid_by = target_user_id;

  UPDATE partnerships SET user2_id = NULL, status = 'archived'
    WHERE user2_id = target_user_id;

  UPDATE partnerships SET user1_id = user2_id, user2_id = NULL, status = 'archived'
    WHERE user1_id = target_user_id AND user2_id IS NOT NULL;

  DELETE FROM categories WHERE partnership_id IN (
    SELECT id FROM partnerships WHERE user1_id = target_user_id);

  DELETE FROM partnerships WHERE user1_id = target_user_id;

  DELETE FROM profiles WHERE id = target_user_id;
END;
$function$;
