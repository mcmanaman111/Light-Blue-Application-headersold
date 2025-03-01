/*
  # Fix notifications policy
  
  1. Changes
     - Drop existing policy
     - Add new policy for notifications with proper checks
     - Ensure users can submit feedback notifications to admins
*/

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;

-- Create new policy with proper checks
CREATE POLICY "Users can insert notifications"
  ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow users to insert notifications for admins (for feedback)
    (
      user_id IN (
        SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
      )
      AND type = 'question_feedback'
    )
    OR
    -- Allow users to insert notifications for themselves
    user_id = auth.uid()
    OR
    -- Allow admins to insert notifications for any user
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );