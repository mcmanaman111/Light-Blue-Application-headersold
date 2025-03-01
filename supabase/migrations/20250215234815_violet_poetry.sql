/*
  # Feedback System Setup
  
  1. New Tables
     - question_feedback: Stores user feedback on questions
     - notifications: Handles system notifications
  
  2. Security
     - Enable RLS on both tables
     - Create policies for user and admin access
     - Add indexes for performance
  
  3. Features
     - Automatic timestamp updates
     - User and admin role separation
     - Notification system integration
*/

-- Drop existing tables if they exist
DROP TABLE IF EXISTS question_feedback CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;

-- Create question_feedback table
CREATE TABLE question_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  question_id text NOT NULL,
  test_id text NOT NULL,
  message text NOT NULL,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  difficulty text NOT NULL CHECK (difficulty IN ('EASY', 'MEDIUM', 'HARD')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'responded')),
  admin_response text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create notifications table
CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  link text,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE question_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for question_feedback
CREATE TRIGGER update_question_feedback_updated_at
  BEFORE UPDATE ON question_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);
CREATE INDEX idx_question_feedback_user_id ON question_feedback(user_id);
CREATE INDEX idx_question_feedback_status ON question_feedback(status);

-- Create policies for question_feedback
CREATE POLICY "Users can insert their own feedback"
  ON question_feedback
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own feedback"
  ON question_feedback
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all feedback"
  ON question_feedback
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Admins can update feedback"
  ON question_feedback
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Create policies for notifications
CREATE POLICY "Users can view their own notifications"
  ON notifications
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
  ON notifications
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

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
      AND auth.uid() IN (
        SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' != 'admin'
      )
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