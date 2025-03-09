/*
  Phase 6: Supporting Features
  
  This migration creates tables for supporting features:
  - notes: User notes related to study materials and questions
  - question_feedback: User feedback on questions
  - notifications: System and user notifications
  
  It also implements triggers and functions for these features.
*/

-- Create notes table
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  test_id INTEGER REFERENCES tests(id) ON DELETE SET NULL,
  topic VARCHAR(255),
  sub_topic VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on notes
CREATE TRIGGER update_notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on notes
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Create question_feedback table
CREATE TABLE question_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  test_id INTEGER REFERENCES tests(id) ON DELETE SET NULL,
  message TEXT NOT NULL,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  difficulty VARCHAR(50) NOT NULL CHECK (difficulty IN ('Easy', 'Medium', 'Hard')),
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved')),
  admin_response TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on question_feedback
CREATE TRIGGER update_question_feedback_updated_at
  BEFORE UPDATE ON question_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on question_feedback
ALTER TABLE question_feedback ENABLE ROW LEVEL SECURITY;

-- Create notifications table
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type VARCHAR(255) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  link TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Create indices
CREATE INDEX idx_notes_user_id ON notes(user_id);
CREATE INDEX idx_notes_question_id ON notes(question_id);
CREATE INDEX idx_notes_test_id ON notes(test_id);
CREATE INDEX idx_notes_topic ON notes(topic);
CREATE INDEX idx_question_feedback_user_id ON question_feedback(user_id);
CREATE INDEX idx_question_feedback_question_id ON question_feedback(question_id);
CREATE INDEX idx_question_feedback_status ON question_feedback(status);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);
CREATE INDEX idx_notifications_type ON notifications(type);

-- Create RLS policies

-- Notes policies (user specific)
CREATE POLICY "Users can view their own notes"
  ON notes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own notes"
  ON notes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own notes"
  ON notes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notes"
  ON notes FOR DELETE
  USING (auth.uid() = user_id);

-- Question feedback policies (user + admin)
CREATE POLICY "Users can view their own feedback"
  ON question_feedback FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all feedback"
  ON question_feedback FOR SELECT
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Users can insert their own feedback"
  ON question_feedback FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pending feedback"
  ON question_feedback FOR UPDATE
  USING (
    auth.uid() = user_id AND status = 'pending'
  )
  WITH CHECK (
    auth.uid() = user_id AND status = 'pending'
  );

CREATE POLICY "Admins can update any feedback"
  ON question_feedback FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Users can delete their own pending feedback"
  ON question_feedback FOR DELETE
  USING (
    auth.uid() = user_id AND status = 'pending'
  );

CREATE POLICY "Admins can delete any feedback"
  ON question_feedback FOR DELETE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Notifications policies (user specific + admin create)
CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notifications"
  ON notifications FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can insert notifications for any user"
  ON notifications FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
    OR user_id = auth.uid()
  );

-- Create functions for supporting features

-- Function to create a notification when feedback is submitted
CREATE OR REPLACE FUNCTION create_feedback_notification() 
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_question_text TEXT;
  v_admin_ids UUID[];
BEGIN
  -- Get question text
  SELECT question_text INTO v_question_text
  FROM questions
  WHERE id = NEW.question_id;
  
  -- Truncate question text if too long
  IF LENGTH(v_question_text) > 50 THEN
    v_question_text := SUBSTR(v_question_text, 1, 47) || '...';
  END IF;
  
  -- Get admin user IDs
  SELECT ARRAY_AGG(id) INTO v_admin_ids
  FROM auth.users
  WHERE raw_user_meta_data->>'role' = 'admin';
  
  -- Create notifications for all admins
  IF v_admin_ids IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link
    )
    SELECT 
      admin_id,
      'question_feedback',
      'New Question Feedback',
      'Feedback on: ' || v_question_text,
      '/admin/feedback/' || NEW.id
    FROM 
      UNNEST(v_admin_ids) AS admin_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for feedback notifications
CREATE TRIGGER create_notification_on_feedback
  AFTER INSERT ON question_feedback
  FOR EACH ROW
  EXECUTE FUNCTION create_feedback_notification();

-- Function to create a notification when feedback is responded to
CREATE OR REPLACE FUNCTION create_feedback_response_notification() 
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Only trigger if admin_response was updated
  IF OLD.admin_response IS DISTINCT FROM NEW.admin_response AND NEW.admin_response IS NOT NULL THEN
    -- Create notification for feedback author
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link
    ) VALUES (
      NEW.user_id,
      'feedback_response',
      'Feedback Response',
      'An administrator has responded to your feedback',
      '/feedback/' || NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for feedback response notifications
CREATE TRIGGER create_notification_on_feedback_response
  AFTER UPDATE ON question_feedback
  FOR EACH ROW
  EXECUTE FUNCTION create_feedback_response_notification();

-- Function to mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read() 
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE notifications
  SET read = true
  WHERE 
    user_id = auth.uid() AND 
    read = false
  RETURNING COUNT(*) INTO v_count;
  
  RETURN v_count;
END;
$$;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count() 
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM notifications
  WHERE 
    user_id = auth.uid() AND 
    read = false;
  
  RETURN v_count;
END;
$$;

-- Function to convert notes to flashcards
CREATE OR REPLACE FUNCTION convert_notes_to_flashcards(
  p_note_ids UUID[],
  p_deck_id INTEGER DEFAULT NULL,
  p_new_deck_title TEXT DEFAULT 'My Notes'
) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_deck_id INTEGER;
  v_note RECORD;
  v_card_count INTEGER := 0;
  v_note_topic TEXT;
  v_note_subtopic TEXT;
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  
  -- Check if notes exist and belong to user
  IF NOT EXISTS (
    SELECT 1 FROM notes 
    WHERE id = ANY(p_note_ids) AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'No valid notes found';
  END IF;
  
  -- Get or create deck
  IF p_deck_id IS NULL THEN
    -- Create new deck
    INSERT INTO flashcard_decks (
      user_id,
      title,
      description
    ) VALUES (
      v_user_id,
      p_new_deck_title,
      'Converted from notes'
    ) RETURNING id INTO v_deck_id;
  ELSE
    -- Verify deck belongs to user
    IF NOT EXISTS (
      SELECT 1 FROM flashcard_decks 
      WHERE id = p_deck_id AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'Deck not found or does not belong to user';
    END IF;
    
    v_deck_id := p_deck_id;
  END IF;
  
  -- Convert notes to flashcards
  FOR v_note IN (
    SELECT 
      n.id,
      n.content,
      n.topic,
      n.sub_topic,
      q.question_text
    FROM 
      notes n
    LEFT JOIN 
      questions q ON n.question_id = q.id
    WHERE 
      n.id = ANY(p_note_ids) 
      AND n.user_id = v_user_id
  ) LOOP
    -- Get topic/subtopic from note or fallback to defaults
    v_note_topic := COALESCE(v_note.topic, 'General');
    v_note_subtopic := v_note.sub_topic;
    
    -- Create flashcard
    INSERT INTO flashcards (
      deck_id,
      front,
      back,
      topic,
      sub_topic
    ) VALUES (
      v_deck_id,
      CASE 
        WHEN v_note.question_text IS NOT NULL 
        THEN v_note.question_text
        ELSE 'Notes: ' || v_note_topic || COALESCE(' - ' || v_note_subtopic, '')
      END,
      v_note.content,
      v_note_topic,
      v_note_subtopic
    );
    
    v_card_count := v_card_count + 1;
  END LOOP;
  
  RETURN v_card_count;
END;
$$;

-- Create view for feedback statistics
CREATE OR REPLACE VIEW feedback_statistics AS
SELECT
  q.topic,
  q.sub_topic,
  COUNT(*) AS feedback_count,
  ROUND(AVG(qf.rating), 2) AS average_rating,
  COUNT(CASE WHEN qf.status = 'pending' THEN 1 END) AS pending_count,
  COUNT(CASE WHEN qf.status = 'reviewed' THEN 1 END) AS reviewed_count,
  COUNT(CASE WHEN qf.status = 'resolved' THEN 1 END) AS resolved_count,
  COUNT(CASE WHEN qf.difficulty = 'Easy' THEN 1 END) AS easy_count,
  COUNT(CASE WHEN qf.difficulty = 'Medium' THEN 1 END) AS medium_count,
  COUNT(CASE WHEN qf.difficulty = 'Hard' THEN 1 END) AS hard_count
FROM
  question_feedback qf
JOIN
  questions q ON qf.question_id = q.id
GROUP BY
  q.topic, q.sub_topic;
