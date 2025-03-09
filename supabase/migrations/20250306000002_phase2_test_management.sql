/*
  Phase 2: Test Management System
  
  This migration creates tables for managing tests and results:
  - tests: Test sessions created by users
  - test_questions: Links questions to tests with order information
  - test_results: User responses to test questions and scores
  
  It also sets up Row Level Security (RLS) policies to protect data access.
*/

-- Create tests table
CREATE TABLE tests (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255),
  mode VARCHAR(255), -- Practice, Simulation, CAT, etc.
  question_count INTEGER,
  topics VARCHAR(255)[], -- Array of topics included in this test
  subtopics VARCHAR(255)[], -- Array of subtopics included in this test
  difficulty VARCHAR(50), -- Easy, Medium, Hard, Mixed
  time_limit_minutes INTEGER,
  status VARCHAR(50) DEFAULT 'in_progress', -- in_progress, completed, abandoned
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ
);

-- Create trigger for updated_at on tests
CREATE TRIGGER update_tests_updated_at
  BEFORE UPDATE ON tests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on tests
ALTER TABLE tests ENABLE ROW LEVEL SECURITY;

-- Create test_questions table
CREATE TABLE test_questions (
  id SERIAL PRIMARY KEY,
  test_id INTEGER REFERENCES tests(id) ON DELETE CASCADE,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  question_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(test_id, question_id)
);

-- Enable RLS on test_questions
ALTER TABLE test_questions ENABLE ROW LEVEL SECURITY;

-- Create test_results table
CREATE TABLE test_results (
  id SERIAL PRIMARY KEY,
  test_id INTEGER REFERENCES tests(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  user_response TEXT[], -- Array of answer IDs or texts selected by the user
  is_correct BOOLEAN,
  score NUMERIC(5,2),
  max_score NUMERIC(5,2),
  time_spent_seconds INTEGER,
  is_flagged BOOLEAN DEFAULT false,
  answered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(test_id, question_id)
);

-- Enable RLS on test_results
ALTER TABLE test_results ENABLE ROW LEVEL SECURITY;

-- Create indices
CREATE INDEX idx_tests_user_id ON tests(user_id);
CREATE INDEX idx_tests_status ON tests(status);
CREATE INDEX idx_test_questions_test_id ON test_questions(test_id);
CREATE INDEX idx_test_questions_question_id ON test_questions(question_id);
CREATE INDEX idx_test_results_test_id ON test_results(test_id);
CREATE INDEX idx_test_results_user_id ON test_results(user_id);
CREATE INDEX idx_test_results_question_id ON test_results(question_id);

-- Create RLS policies

-- Tests policies (user specific)
CREATE POLICY "Users can view their own tests"
  ON tests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tests"
  ON tests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tests"
  ON tests FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tests"
  ON tests FOR DELETE
  USING (auth.uid() = user_id);

-- Test questions policies
CREATE POLICY "Users can view questions for their own tests"
  ON test_questions FOR SELECT
  USING (
    test_id IN (
      SELECT id FROM tests WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert questions for their own tests"
  ON test_questions FOR INSERT
  WITH CHECK (
    test_id IN (
      SELECT id FROM tests WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update questions for their own tests"
  ON test_questions FOR UPDATE
  USING (
    test_id IN (
      SELECT id FROM tests WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    test_id IN (
      SELECT id FROM tests WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete questions for their own tests"
  ON test_questions FOR DELETE
  USING (
    test_id IN (
      SELECT id FROM tests WHERE user_id = auth.uid()
    )
  );

-- Test results policies
CREATE POLICY "Users can view their own test results"
  ON test_results FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own test results"
  ON test_results FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own test results"
  ON test_results FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own test results"
  ON test_results FOR DELETE
  USING (auth.uid() = user_id);

-- Create view for test summaries
CREATE OR REPLACE VIEW test_summaries AS
SELECT
  t.id AS test_id,
  t.user_id,
  t.title,
  t.mode,
  t.question_count,
  t.topics,
  t.subtopics,
  t.difficulty,
  t.status,
  t.created_at,
  t.started_at,
  t.finished_at,
  COALESCE(SUM(tr.score), 0) AS total_score,
  COALESCE(SUM(tr.max_score), 0) AS total_possible_score,
  COALESCE(COUNT(tr.id), 0) AS answered_questions,
  COALESCE(SUM(CASE WHEN tr.is_correct THEN 1 ELSE 0 END), 0) AS correct_answers,
  CASE
    WHEN COALESCE(SUM(tr.max_score), 0) > 0 
    THEN COALESCE(SUM(tr.score), 0) / COALESCE(SUM(tr.max_score), 0) * 100
    ELSE 0
  END AS percentage_score,
  CASE 
    WHEN t.started_at IS NOT NULL AND t.finished_at IS NOT NULL 
    THEN EXTRACT(EPOCH FROM (t.finished_at - t.started_at)) / 60
    ELSE NULL
  END AS duration_minutes
FROM
  tests t
LEFT JOIN
  test_results tr ON t.id = tr.test_id
GROUP BY
  t.id, t.user_id, t.title, t.mode, t.question_count, t.topics, t.subtopics, 
  t.difficulty, t.status, t.created_at, t.started_at, t.finished_at;

-- Create function to get next question for a test
CREATE OR REPLACE FUNCTION get_next_test_question(p_test_id INTEGER)
RETURNS TABLE (
  question_id INTEGER,
  question_order INTEGER,
  question_text TEXT,
  question_format VARCHAR(255),
  answers JSON[]
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH next_question AS (
    SELECT 
      q.id,
      tq.question_order,
      q.question_text,
      q.question_format
    FROM 
      test_questions tq
    JOIN 
      questions q ON tq.question_id = q.id
    LEFT JOIN 
      test_results tr ON tq.test_id = tr.test_id AND tq.question_id = tr.question_id
    WHERE 
      tq.test_id = p_test_id
      AND tr.id IS NULL
    ORDER BY 
      tq.question_order
    LIMIT 1
  )
  SELECT 
    nq.id,
    nq.question_order,
    nq.question_text,
    nq.question_format,
    ARRAY_AGG(
      json_build_object(
        'id', a.id,
        'option_number', a.option_number,
        'answer_text', a.answer_text
      )
    ) AS answers
  FROM 
    next_question nq
  JOIN 
    answers a ON nq.id = a.question_id
  GROUP BY 
    nq.id, nq.question_order, nq.question_text, nq.question_format;
END;
$$;

-- Create function to submit an answer to a test question
CREATE OR REPLACE FUNCTION submit_test_answer(
  p_test_id INTEGER,
  p_question_id INTEGER, 
  p_user_response TEXT[],
  p_time_spent_seconds INTEGER,
  p_is_flagged BOOLEAN DEFAULT false
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_is_correct BOOLEAN;
  v_score NUMERIC(5,2) := 0;
  v_max_score NUMERIC(5,2) := 1;
  v_answer_id INTEGER;
  v_result_id INTEGER;
  v_question_format TEXT;
  v_use_partial_scoring BOOLEAN;
  v_status TEXT;
BEGIN
  -- Get the current user
  v_user_id := auth.uid();
  
  -- Verify the test belongs to the user
  IF NOT EXISTS (SELECT 1 FROM tests WHERE id = p_test_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'Test not found or does not belong to the current user';
  END IF;
  
  -- Get question info
  SELECT 
    question_format,
    use_partial_scoring
  INTO 
    v_question_format,
    v_use_partial_scoring
  FROM 
    questions
  WHERE 
    id = p_question_id;
  
  -- Calculate score based on question type
  IF v_question_format = 'Multiple Choice' THEN
    -- For Multiple Choice, check if selected answer is correct
    SELECT 
      is_correct INTO v_is_correct
    FROM 
      answers
    WHERE 
      question_id = p_question_id
      AND id::text = p_user_response[1];
      
    IF v_is_correct THEN
      v_score := 1;
    ELSE
      v_score := 0;
    END IF;
    
  ELSIF v_question_format = 'Select All That Apply' AND v_use_partial_scoring THEN
    -- For SATA with partial scoring, calculate based on selected answers
    SELECT 
      COALESCE(
        SUM(
          CASE
            WHEN a.id::text = ANY(p_user_response) AND a.is_correct THEN a.partial_credit
            WHEN a.id::text = ANY(p_user_response) AND NOT a.is_correct THEN -a.penalty_value
            WHEN a.id::text <> ALL(p_user_response) AND a.is_correct THEN -a.partial_credit
            ELSE 0
          END
        ),
        0
      ) INTO v_score
    FROM 
      answers a
    WHERE 
      a.question_id = p_question_id;
    
    -- Ensure score is not negative
    v_score := GREATEST(v_score, 0);
    -- Set maximum score for SATA
    SELECT COUNT(*) INTO v_max_score FROM answers WHERE question_id = p_question_id AND is_correct;
    
    -- Determine overall correctness
    v_is_correct := (v_score = v_max_score);
    
  ELSE
    -- For other question types or SATA without partial scoring
    -- Check if all correct answers are selected and no incorrect answers are selected
    IF NOT EXISTS (
      -- Check if any correct answer is not selected
      SELECT 1 FROM answers 
      WHERE question_id = p_question_id 
        AND is_correct 
        AND id::text <> ALL(p_user_response)
    ) AND NOT EXISTS (
      -- Check if any incorrect answer is selected
      SELECT 1 FROM answers 
      WHERE question_id = p_question_id 
        AND NOT is_correct 
        AND id::text = ANY(p_user_response)
    ) THEN
      v_is_correct := TRUE;
      v_score := 1;
    ELSE
      v_is_correct := FALSE;
      v_score := 0;
    END IF;
  END IF;
  
  -- Update user_question_status if it exists, otherwise insert it
  SELECT status INTO v_status FROM user_question_status 
  WHERE user_id = v_user_id AND question_id = p_question_id;
  
  IF v_status IS NULL THEN
    -- Insert new record
    INSERT INTO user_question_status (
      user_id,
      question_id,
      status,
      attempt_count,
      last_seen_at
    ) VALUES (
      v_user_id,
      p_question_id,
      CASE WHEN v_is_correct THEN 'correct' ELSE 'incorrect' END,
      1,
      NOW()
    );
  ELSE
    -- Update existing record
    UPDATE user_question_status
    SET 
      status = CASE WHEN v_is_correct THEN 'correct' ELSE 'incorrect' END,
      attempt_count = attempt_count + 1,
      last_seen_at = NOW()
    WHERE 
      user_id = v_user_id AND question_id = p_question_id;
  END IF;
  
  -- Insert test result
  INSERT INTO test_results (
    test_id,
    user_id,
    question_id,
    user_response,
    is_correct,
    score,
    max_score,
    time_spent_seconds,
    is_flagged
  ) VALUES (
    p_test_id,
    v_user_id,
    p_question_id,
    p_user_response,
    v_is_correct,
    v_score,
    v_max_score,
    p_time_spent_seconds,
    p_is_flagged
  )
  RETURNING id INTO v_result_id;
  
  -- Return result
  RETURN json_build_object(
    'result_id', v_result_id,
    'is_correct', v_is_correct,
    'score', v_score,
    'max_score', v_max_score
  );
END;
$$;
