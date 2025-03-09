/*
  Phase 1: Core Question Bank Structure
  
  This migration creates the foundational tables for the NCLEX question bank:
  - topics: Main nursing topics covered in the NCLEX exam
  - subtopics: Specific nursing subtopics within each main topic
  - questions: NCLEX-style questions for practice and exams
  - answers: Answer options for each question
  - user_question_status: Tracks each user's interaction with each question
  
  It also sets up Row Level Security (RLS) policies to protect data access.
*/

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create topics table
CREATE TABLE topics (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on topics
CREATE TRIGGER update_topics_updated_at
  BEFORE UPDATE ON topics
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on topics
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;

-- Create subtopics table
CREATE TABLE subtopics (
  id SERIAL PRIMARY KEY,
  topic_id INTEGER REFERENCES topics(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on subtopics
CREATE TRIGGER update_subtopics_updated_at
  BEFORE UPDATE ON subtopics
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on subtopics
ALTER TABLE subtopics ENABLE ROW LEVEL SECURITY;

-- Create questions table
CREATE TABLE questions (
  id SERIAL PRIMARY KEY,
  topic VARCHAR(255) NOT NULL,
  sub_topic VARCHAR(255) NOT NULL,
  question_format VARCHAR(255) NOT NULL, -- Multiple Choice, SATA, etc.
  ngn BOOLEAN NOT NULL DEFAULT false, -- Next Generation NCLEX flag
  difficulty VARCHAR(50) NOT NULL, -- Easy, Medium, Hard
  question_text TEXT NOT NULL,
  explanation TEXT,
  use_partial_scoring BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on questions
CREATE TRIGGER update_questions_updated_at
  BEFORE UPDATE ON questions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on questions
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;

-- Create answers table
CREATE TABLE answers (
  id SERIAL PRIMARY KEY,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  option_number INTEGER NOT NULL, -- 1, 2, 3, 4, etc.
  answer_text TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL DEFAULT false,
  partial_credit NUMERIC(3,2) NOT NULL DEFAULT 0.00, -- For SATA questions
  penalty_value NUMERIC(3,2) NOT NULL DEFAULT 0.00,  -- For SATA questions
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on answers
CREATE TRIGGER update_answers_updated_at
  BEFORE UPDATE ON answers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on answers
ALTER TABLE answers ENABLE ROW LEVEL SECURITY;

-- Create user_question_status table
CREATE TABLE user_question_status (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL DEFAULT 'unseen', -- unseen, correct, incorrect, marked, skipped
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_seen_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, question_id)
);

-- Create trigger for updated_at on user_question_status
CREATE TRIGGER update_user_question_status_updated_at
  BEFORE UPDATE ON user_question_status
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on user_question_status
ALTER TABLE user_question_status ENABLE ROW LEVEL SECURITY;

-- Create indices
CREATE INDEX idx_questions_topic ON questions(topic);
CREATE INDEX idx_questions_sub_topic ON questions(sub_topic);
CREATE INDEX idx_questions_difficulty ON questions(difficulty);
CREATE INDEX idx_questions_question_format ON questions(question_format);
CREATE INDEX idx_answers_question_id ON answers(question_id);
CREATE INDEX idx_user_question_status_user_id ON user_question_status(user_id);
CREATE INDEX idx_user_question_status_question_id ON user_question_status(question_id);
CREATE INDEX idx_user_question_status_status ON user_question_status(status);
CREATE INDEX idx_subtopics_topic_id ON subtopics(topic_id);

-- Create RLS policies

-- Topics policies (public read, admin write)
CREATE POLICY "Anyone can view topics"
  ON topics FOR SELECT
  USING (true);

CREATE POLICY "Only admins can insert topics"
  ON topics FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Only admins can update topics"
  ON topics FOR UPDATE
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

CREATE POLICY "Only admins can delete topics"
  ON topics FOR DELETE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Subtopics policies (public read, admin write)
CREATE POLICY "Anyone can view subtopics"
  ON subtopics FOR SELECT
  USING (true);

CREATE POLICY "Only admins can insert subtopics"
  ON subtopics FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Only admins can update subtopics"
  ON subtopics FOR UPDATE
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

CREATE POLICY "Only admins can delete subtopics"
  ON subtopics FOR DELETE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Questions policies (public read, admin write)
CREATE POLICY "Anyone can view questions"
  ON questions FOR SELECT
  USING (true);

CREATE POLICY "Only admins can insert questions"
  ON questions FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Only admins can update questions"
  ON questions FOR UPDATE
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

CREATE POLICY "Only admins can delete questions"
  ON questions FOR DELETE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Answers policies (public read, admin write)
CREATE POLICY "Anyone can view answers"
  ON answers FOR SELECT
  USING (true);

CREATE POLICY "Only admins can insert answers"
  ON answers FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Only admins can update answers"
  ON answers FOR UPDATE
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

CREATE POLICY "Only admins can delete answers"
  ON answers FOR DELETE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

-- User question status policies (user specific)
CREATE POLICY "Users can view their own question status"
  ON user_question_status FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own question status"
  ON user_question_status FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own question status"
  ON user_question_status FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own question status"
  ON user_question_status FOR DELETE
  USING (auth.uid() = user_id);

-- Create view for unseen questions
CREATE OR REPLACE VIEW user_unseen_questions AS
SELECT 
  q.id AS question_id,
  q.topic,
  q.sub_topic,
  q.difficulty,
  q.question_format,
  q.ngn,
  u.id AS user_id
FROM 
  questions q
CROSS JOIN
  auth.users u
LEFT JOIN
  user_question_status uqs ON q.id = uqs.question_id AND u.id = uqs.user_id
WHERE
  uqs.id IS NULL;

-- Create view for user question statistics
CREATE OR REPLACE VIEW user_question_statistics AS
SELECT
  user_id,
  topic,
  sub_topic,
  COUNT(*) AS total_questions,
  SUM(CASE WHEN status = 'correct' THEN 1 ELSE 0 END) AS correct_count,
  SUM(CASE WHEN status = 'incorrect' THEN 1 ELSE 0 END) AS incorrect_count,
  SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) AS skipped_count,
  SUM(CASE WHEN status = 'marked' THEN 1 ELSE 0 END) AS marked_count,
  SUM(CASE WHEN status = 'unseen' OR status IS NULL THEN 1 ELSE 0 END) AS unseen_count
FROM
  user_question_status uqs
RIGHT JOIN
  questions q ON uqs.question_id = q.id
GROUP BY
  user_id, topic, sub_topic;
