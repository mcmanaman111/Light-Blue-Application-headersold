/*
  # Add admin notifications policy
  
  1. Changes
     - Add policy to allow admins to insert notifications for any user
     - This enables admins to create notifications in response to feedback
*/

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Admins can insert notifications for any user" ON notifications;

-- Create new policy
CREATE POLICY "Admins can insert notifications for any user"
  ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );