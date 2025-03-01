/*
  # Add user notifications policy
  
  1. Changes
     - Add policy to allow users to insert notifications
     - This enables users to create notifications when submitting feedback
*/

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;

-- Create new policy
CREATE POLICY "Users can insert notifications"
  ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow users to insert notifications for admins
    user_id IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
    OR
    -- Allow users to insert notifications for themselves
    user_id = auth.uid()
  );