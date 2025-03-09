/*
  Phase 4: CAT Implementation
  
  This migration creates tables for Computer Adaptive Testing (CAT):
  - cat_sessions: Tracks CAT testing sessions
  - question_difficulty_parameters: Item Response Theory parameters for questions
  - cat_question_selections: Log of questions selected by CAT algorithm
  
  It also implements the CAT algorithm functions for:
  - Ability estimation
  - Question selection based on maximum information
  - Test termination criteria
*/

-- Create cat_sessions table
CREATE TABLE cat_sessions (
  id SERIAL PRIMARY KEY,
  test_id INTEGER REFERENCES tests(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  initial_ability NUMERIC(5,2) DEFAULT 0,
  current_ability NUMERIC(5,2) DEFAULT 0,
  ability_confidence NUMERIC(5,2) DEFAULT 0,
  passing_standard NUMERIC(5,2) DEFAULT 0,
  min_questions INTEGER DEFAULT 75,
  max_questions INTEGER DEFAULT 145,
  questions_answered INTEGER DEFAULT 0,
  status VARCHAR(50) DEFAULT 'in_progress', -- in_progress, passed, failed, abandoned
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on cat_sessions
CREATE TRIGGER update_cat_sessions_updated_at
  BEFORE UPDATE ON cat_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on cat_sessions
ALTER TABLE cat_sessions ENABLE ROW LEVEL SECURITY;

-- Create question_difficulty_parameters table
CREATE TABLE question_difficulty_parameters (
  id SERIAL PRIMARY KEY,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  discrimination NUMERIC(5,2) DEFAULT 1, -- a-parameter in IRT
  difficulty NUMERIC(5,2) DEFAULT 0, -- b-parameter in IRT
  guessing NUMERIC(5,2) DEFAULT 0, -- c-parameter in IRT
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(question_id)
);

-- Create trigger for updated_at on question_difficulty_parameters
CREATE TRIGGER update_question_difficulty_parameters_updated_at
  BEFORE UPDATE ON question_difficulty_parameters
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on question_difficulty_parameters
ALTER TABLE question_difficulty_parameters ENABLE ROW LEVEL SECURITY;

-- Create cat_question_selections table
CREATE TABLE cat_question_selections (
  id SERIAL PRIMARY KEY,
  cat_session_id INTEGER REFERENCES cat_sessions(id) ON DELETE CASCADE,
  question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  ability_estimate_before NUMERIC(5,2),
  ability_estimate_after NUMERIC(5,2),
  information_value NUMERIC(5,2),
  was_correct BOOLEAN,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on cat_question_selections
ALTER TABLE cat_question_selections ENABLE ROW LEVEL SECURITY;

-- Create indices
CREATE INDEX idx_cat_sessions_test_id ON cat_sessions(test_id);
CREATE INDEX idx_cat_sessions_user_id ON cat_sessions(user_id);
CREATE INDEX idx_cat_sessions_status ON cat_sessions(status);
CREATE INDEX idx_question_difficulty_parameters_question_id ON question_difficulty_parameters(question_id);
CREATE INDEX idx_cat_question_selections_cat_session_id ON cat_question_selections(cat_session_id);
CREATE INDEX idx_cat_question_selections_question_id ON cat_question_selections(question_id);
CREATE INDEX idx_cat_question_selections_position ON cat_question_selections(position);

-- Create RLS policies

-- CAT sessions policies (user specific)
CREATE POLICY "Users can view their own CAT sessions"
  ON cat_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own CAT sessions"
  ON cat_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own CAT sessions"
  ON cat_sessions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own CAT sessions"
  ON cat_sessions FOR DELETE
  USING (auth.uid() = user_id);

-- Question difficulty parameters policies (public read, admin write)
CREATE POLICY "Anyone can view question difficulty parameters"
  ON question_difficulty_parameters FOR SELECT
  USING (true);

CREATE POLICY "Only admins can insert question difficulty parameters"
  ON question_difficulty_parameters FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

CREATE POLICY "Only admins can update question difficulty parameters"
  ON question_difficulty_parameters FOR UPDATE
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

CREATE POLICY "Only admins can delete question difficulty parameters"
  ON question_difficulty_parameters FOR DELETE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
    )
  );

-- CAT question selections policies
CREATE POLICY "Users can view their own CAT question selections"
  ON cat_question_selections FOR SELECT
  USING (
    cat_session_id IN (
      SELECT id FROM cat_sessions WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own CAT question selections"
  ON cat_question_selections FOR INSERT
  WITH CHECK (
    cat_session_id IN (
      SELECT id FROM cat_sessions WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own CAT question selections"
  ON cat_question_selections FOR UPDATE
  USING (
    cat_session_id IN (
      SELECT id FROM cat_sessions WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    cat_session_id IN (
      SELECT id FROM cat_sessions WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own CAT question selections"
  ON cat_question_selections FOR DELETE
  USING (
    cat_session_id IN (
      SELECT id FROM cat_sessions WHERE user_id = auth.uid()
    )
  );

-- Create CAT algorithm functions

-- Function to calculate probability of correct response using 3PL IRT model
CREATE OR REPLACE FUNCTION calculate_probability(
  ability NUMERIC,
  discrimination NUMERIC,
  difficulty NUMERIC,
  guessing NUMERIC
) RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE
  logit NUMERIC;
  probability NUMERIC;
BEGIN
  -- 3PL model: P(θ) = c + (1-c) / (1 + e^(-a(θ-b)))
  logit := discrimination * (ability - difficulty);
  
  -- Handle extreme values to prevent overflow
  IF logit > 35.0 THEN
    logit := 35.0;
  ELSIF logit < -35.0 THEN
    logit := -35.0;
  END IF;
  
  probability := guessing + (1.0 - guessing) / (1.0 + exp(-logit));
  RETURN probability;
END;
$$;

-- Function to calculate item information function
CREATE OR REPLACE FUNCTION calculate_information(
  ability NUMERIC,
  discrimination NUMERIC,
  difficulty NUMERIC,
  guessing NUMERIC
) RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE
  probability NUMERIC;
  information NUMERIC;
BEGIN
  probability := calculate_probability(ability, discrimination, difficulty, guessing);
  
  -- Item information function: I(θ) = a² * (P(θ) - c)² / ((1-c)² * P(θ) * (1-P(θ)))
  IF guessing > 0.0 AND guessing < 1.0 AND probability > guessing AND probability < 1.0 THEN
    information := (discrimination * discrimination * (probability - guessing) * (probability - guessing)) / 
                  ((1.0 - guessing) * (1.0 - guessing) * probability * (1.0 - probability));
  ELSE
    -- For simpler cases (or to avoid division by zero)
    information := discrimination * discrimination * probability * (1.0 - probability);
  END IF;
  
  RETURN information;
END;
$$;

-- Function to estimate ability using Maximum Likelihood Estimation (MLE)
CREATE OR REPLACE FUNCTION estimate_ability_mle(
  p_cat_session_id INTEGER
) RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE
  v_ability NUMERIC := 0.0;
  v_prev_ability NUMERIC := -999.0;
  v_step NUMERIC := 0.1;
  v_iter INTEGER := 0;
  v_max_iter INTEGER := 50;
  v_likelihood_derivative NUMERIC;
  v_likelihood_second_derivative NUMERIC;
  v_selection RECORD;
  v_discrimination NUMERIC;
  v_difficulty NUMERIC;
  v_guessing NUMERIC;
  v_probability NUMERIC;
  v_correct BOOLEAN;
BEGIN
  -- Get initial ability estimate if exists
  SELECT current_ability INTO v_ability
  FROM cat_sessions
  WHERE id = p_cat_session_id;
  
  -- Newton-Raphson method to find MLE
  WHILE ABS(v_ability - v_prev_ability) > 0.001 AND v_iter < v_max_iter LOOP
    v_prev_ability := v_ability;
    v_likelihood_derivative := 0.0;
    v_likelihood_second_derivative := 0.0;
    
    -- Iterate through all answered questions
    FOR v_selection IN (
      SELECT 
        cqs.was_correct,
        qdp.discrimination,
        qdp.difficulty,
        qdp.guessing
      FROM 
        cat_question_selections cqs
      JOIN 
        question_difficulty_parameters qdp ON cqs.question_id = qdp.question_id
      WHERE 
        cqs.cat_session_id = p_cat_session_id
    ) LOOP
      v_discrimination := v_selection.discrimination;
      v_difficulty := v_selection.difficulty;
      v_guessing := v_selection.guessing;
      v_correct := v_selection.was_correct;
      
      -- Calculate probability of correct response at current ability
      v_probability := calculate_probability(v_ability, v_discrimination, v_difficulty, v_guessing);
      
      -- Limit probability to avoid division by zero
      IF v_probability < 0.001 THEN v_probability := 0.001; END IF;
      IF v_probability > 0.999 THEN v_probability := 0.999; END IF;
      
      -- Update likelihood derivatives
      IF v_correct THEN
        v_likelihood_derivative := v_likelihood_derivative + 
          v_discrimination * (1.0 - v_probability) / v_probability;
      ELSE
        v_likelihood_derivative := v_likelihood_derivative - 
          v_discrimination * v_probability / (1.0 - v_probability);
      END IF;
      
      -- Second derivative for Newton-Raphson
      v_likelihood_second_derivative := v_likelihood_second_derivative - 
        v_discrimination * v_discrimination * v_probability * (1.0 - v_probability);
    END LOOP;
    
    -- Update ability estimate using Newton-Raphson step
    IF v_likelihood_second_derivative <> 0 THEN
      v_ability := v_ability - v_likelihood_derivative / v_likelihood_second_derivative;
    ELSE
      v_ability := v_ability + v_step * SIGN(v_likelihood_derivative);
    END IF;
    
    -- Bound ability to reasonable range (-4 to 4 in logit scale)
    IF v_ability < -4.0 THEN v_ability := -4.0; END IF;
    IF v_ability > 4.0 THEN v_ability := 4.0; END IF;
    
    v_iter := v_iter + 1;
  END LOOP;
  
  RETURN v_ability;
END;
$$;

-- Function to get next question for CAT test
CREATE OR REPLACE FUNCTION get_next_cat_question(
  p_cat_session_id INTEGER
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_test_id INTEGER;
  v_ability NUMERIC;
  v_questions_answered INTEGER;
  v_min_questions INTEGER;
  v_max_questions INTEGER;
  v_passing_standard NUMERIC;
  v_next_question_id INTEGER;
  v_next_question RECORD;
  v_max_info NUMERIC := 0;
  v_info NUMERIC;
  v_status VARCHAR;
  v_test_complete BOOLEAN := FALSE;
  v_pass_fail_decision VARCHAR;
BEGIN
  -- Get session info
  SELECT 
    user_id,
    test_id,
    current_ability,
    questions_answered,
    min_questions,
    max_questions,
    passing_standard,
    status
  INTO 
    v_user_id,
    v_test_id,
    v_ability,
    v_questions_answered,
    v_min_questions,
    v_max_questions,
    v_passing_standard,
    v_status
  FROM 
    cat_sessions
  WHERE 
    id = p_cat_session_id;
  
  -- Check if user is authorized
  IF auth.uid() <> v_user_id THEN
    RAISE EXCEPTION 'Not authorized to access this CAT session';
  END IF;
  
  -- Check if test is already complete
  IF v_status <> 'in_progress' THEN
    RETURN json_build_object(
      'status', v_status,
      'message', 'Test already completed with status: ' || v_status,
      'ability', v_ability,
      'questions_answered', v_questions_answered
    );
  END IF;
  
  -- Check if we've reached max questions
  IF v_questions_answered >= v_max_questions THEN
    v_test_complete := TRUE;
    v_pass_fail_decision := CASE WHEN v_ability >= v_passing_standard THEN 'passed' ELSE 'failed' END;
  
  -- Check if we've reached min questions and can make a confident pass/fail decision
  ELSIF v_questions_answered >= v_min_questions THEN
    -- Calculate confidence (this is simplified - real NCLEX uses more complex criteria)
    IF ABS(v_ability - v_passing_standard) > 1.0 THEN
      v_test_complete := TRUE;
      v_pass_fail_decision := CASE WHEN v_ability >= v_passing_standard THEN 'passed' ELSE 'failed' END;
    END IF;
  END IF;
  
  -- If test is complete, update status and return result
  IF v_test_complete THEN
    UPDATE cat_sessions
    SET 
      status = v_pass_fail_decision,
      updated_at = now()
    WHERE 
      id = p_cat_session_id;
      
    UPDATE tests
    SET 
      status = 'completed',
      finished_at = now()
    WHERE 
      id = v_test_id;
      
    RETURN json_build_object(
      'status', v_pass_fail_decision,
      'message', 'Test completed with status: ' || v_pass_fail_decision,
      'ability', v_ability,
      'questions_answered', v_questions_answered
    );
  END IF;
  
  -- Find the question with maximum information at current ability
  FOR v_next_question IN (
    SELECT 
      q.id,
      q.topic,
      q.sub_topic,
      q.question_format,
      q.question_text,
      qdp.discrimination,
      qdp.difficulty,
      qdp.guessing
    FROM 
      questions q
    JOIN 
      question_difficulty_parameters qdp ON q.id = qdp.question_id
    JOIN 
      test_questions tq ON q.id = tq.question_id AND tq.test_id = v_test_id
    LEFT JOIN 
      cat_question_selections cqs ON q.id = cqs.question_id AND cqs.cat_session_id = p_cat_session_id
    WHERE 
      cqs.id IS NULL -- Only questions not yet answered
    ORDER BY 
      -- Default ordering for edge cases
      RANDOM()
    LIMIT 50 -- Limit to a reasonable number for performance
  ) LOOP
    -- Calculate information value for this question at current ability
    v_info := calculate_information(
      v_ability, 
      v_next_question.discrimination, 
      v_next_question.difficulty, 
      v_next_question.guessing
    );
    
    -- Keep track of question with maximum information
    IF v_info > v_max_info THEN
      v_max_info := v_info;
      v_next_question_id := v_next_question.id;
    END IF;
  END LOOP;
  
  -- If no question was found (should be rare), pick a random one
  IF v_next_question_id IS NULL THEN
    SELECT 
      q.id INTO v_next_question_id
    FROM 
      questions q
    JOIN 
      test_questions tq ON q.id = tq.question_id AND tq.test_id = v_test_id
    LEFT JOIN 
      cat_question_selections cqs ON q.id = cqs.question_id AND cqs.cat_session_id = p_cat_session_id
    WHERE 
      cqs.id IS NULL
    ORDER BY RANDOM()
    LIMIT 1;
  END IF;
  
  -- Record the question selection
  INSERT INTO cat_question_selections (
    cat_session_id,
    question_id,
    position,
    ability_estimate_before,
    information_value
  ) VALUES (
    p_cat_session_id,
    v_next_question_id,
    v_questions_answered + 1,
    v_ability,
    v_max_info
  );
  
  -- Update questions answered count
  UPDATE cat_sessions
  SET 
    questions_answered = questions_answered + 1,
    updated_at = now()
  WHERE 
    id = p_cat_session_id;
  
  -- Get question details to return
  SELECT 
    q.id,
    q.question_text,
    q.question_format,
    q.topic,
    q.sub_topic,
    q.difficulty,
    array_agg(
      json_build_object(
        'id', a.id,
        'option_number', a.option_number,
        'answer_text', a.answer_text
      )
    ) AS answers
  INTO v_next_question
  FROM 
    questions q
  JOIN 
    answers a ON q.id = a.question_id
  WHERE 
    q.id = v_next_question_id
  GROUP BY 
    q.id, q.question_text, q.question_format, q.topic, q.sub_topic, q.difficulty;
  
  -- Return the next question
  RETURN json_build_object(
    'question_id', v_next_question.id,
    'question_text', v_next_question.question_text,
    'question_format', v_next_question.question_format,
    'topic', v_next_question.topic,
    'sub_topic', v_next_question.sub_topic,
    'difficulty', v_next_question.difficulty,
    'answers', v_next_question.answers,
    'question_number', v_questions_answered + 1
  );
END;
$$;

-- Function to submit an answer to a CAT question
CREATE OR REPLACE FUNCTION submit_cat_answer(
  p_cat_session_id INTEGER,
  p_question_id INTEGER,
  p_user_response TEXT[],
  p_time_spent_seconds INTEGER
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_test_id INTEGER;
  v_result JSON;
  v_is_correct BOOLEAN;
  v_score NUMERIC;
  v_ability NUMERIC;
  v_selection_id INTEGER;
BEGIN
  -- Get user_id and test_id from session
  SELECT 
    user_id, 
    test_id,
    current_ability
  INTO 
    v_user_id, 
    v_test_id,
    v_ability
  FROM 
    cat_sessions
  WHERE 
    id = p_cat_session_id;
  
  -- Check authorization
  IF auth.uid() <> v_user_id THEN
    RAISE EXCEPTION 'Not authorized to submit answers for this CAT session';
  END IF;
  
  -- Submit answer to test_results
  v_result := submit_test_answer(
    v_test_id,
    p_question_id,
    p_user_response,
    p_time_spent_seconds
  );
  
  -- Extract is_correct from result
  v_is_correct := (v_result->>'is_correct')::BOOLEAN;
  v_score := (v_result->>'score')::NUMERIC;
  
  -- Update cat_question_selection with result
  UPDATE cat_question_selections
  SET 
    was_correct = v_is_correct
  WHERE 
    cat_session_id = p_cat_session_id
    AND question_id = p_question_id
  RETURNING id INTO v_selection_id;
  
  -- Re-estimate ability
  v_ability := estimate_ability_mle(p_cat_session_id);
  
  -- Update ability estimate
  UPDATE cat_question_selections
  SET 
    ability_estimate_after = v_ability
  WHERE 
    id = v_selection_id;
  
  -- Update cat_session
  UPDATE cat_sessions
  SET 
    current_ability = v_ability,
    updated_at = now()
  WHERE 
    id = p_cat_session_id;
  
  -- Return updated result
  RETURN json_build_object(
    'is_correct', v_is_correct,
    'score', v_score,
    'ability', v_ability,
    'questions_answered', (SELECT questions_answered FROM cat_sessions WHERE id = p_cat_session_id)
  );
END;
$$;

-- Function to initialize CAT parameters based on question difficulty
CREATE OR REPLACE FUNCTION initialize_cat_parameters() 
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_question RECORD;
  v_difficulty NUMERIC;
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM auth.users 
    WHERE id = auth.uid() AND raw_user_meta_data->>'role' = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only administrators can initialize CAT parameters';
  END IF;

  -- Process each question without parameters
  FOR v_question IN (
    SELECT 
      q.id,
      q.difficulty
    FROM 
      questions q
    LEFT JOIN 
      question_difficulty_parameters qdp ON q.id = qdp.question_id
    WHERE 
      qdp.id IS NULL
  ) LOOP
    -- Convert text difficulty to numeric
    CASE v_question.difficulty
      WHEN 'Easy' THEN v_difficulty := -1.0;
      WHEN 'Medium' THEN v_difficulty := 0.0;
      WHEN 'Hard' THEN v_difficulty := 1.0;
      ELSE v_difficulty := 0.0;
    END CASE;
    
    -- Add small random variation
    v_difficulty := v_difficulty + (random() * 0.5 - 0.25);
    
    -- Insert default parameters
    INSERT INTO question_difficulty_parameters (
      question_id,
      discrimination,
      difficulty,
      guessing
    ) VALUES (
      v_question.id,
      0.8 + random() * 0.4, -- discrimination between 0.8 and 1.2
      v_difficulty,
      0.20 + random() * 0.05 -- guessing between 0.20 and 0.25 for 4-option MCQ
    );
  END LOOP;
END;
$$;

-- Function to create a new CAT test
CREATE OR REPLACE FUNCTION create_cat_test(
  p_title TEXT DEFAULT 'NCLEX CAT Simulation',
  p_topics TEXT[] DEFAULT NULL,
  p_min_questions INTEGER DEFAULT 75,
  p_max_questions INTEGER DEFAULT 145,
  p_passing_standard NUMERIC DEFAULT 0.0
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_test_id INTEGER;
  v_cat_session_id INTEGER;
  v_initial_ability NUMERIC := 0.0;
  v_question_pool INTEGER := 300; -- Number of questions to include in the test
  v_question_count INTEGER;
  v_question RECORD;
  v_question_ids INTEGER[] := '{}';
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  
  -- Create new test
  INSERT INTO tests (
    user_id,
    title,
    mode,
    topics,
    status,
    created_at,
    started_at
  ) VALUES (
    v_user_id,
    p_title,
    'CAT',
    p_topics,
    'in_progress',
    now(),
    now()
  ) RETURNING id INTO v_test_id;
  
  -- Select questions for the test pool
  -- If topics specified, filter by topics
  IF p_topics IS NOT NULL AND array_length(p_topics, 1) > 0 THEN
    FOR v_question IN (
      SELECT 
        q.id
      FROM 
        questions q
      JOIN 
        question_difficulty_parameters qdp ON q.id = qdp.question_id
      LEFT JOIN 
        user_question_status uqs ON q.id = uqs.question_id AND uqs.user_id = v_user_id
      WHERE 
        q.topic = ANY(p_topics)
        AND (uqs.id IS NULL OR uqs.status <> 'correct')
      ORDER BY 
        -- Include a mix of questions by difficulty and status
        CASE 
          WHEN uqs.id IS NULL THEN 1 -- Unseen questions first
          WHEN uqs.status = 'incorrect' THEN 2 -- Incorrect questions next
          ELSE 3 -- Other statuses last
        END,
        RANDOM()
      LIMIT v_question_pool
    ) LOOP
      v_question_ids := v_question_ids || v_question.id;
    END LOOP;
  ELSE
    -- No topics specified, select from all questions
    FOR v_question IN (
      SELECT 
        q.id
      FROM 
        questions q
      JOIN 
        question_difficulty_parameters qdp ON q.id = qdp.question_id
      LEFT JOIN 
        user_question_status uqs ON q.id = uqs.question_id AND uqs.user_id = v_user_id
      ORDER BY 
        CASE 
          WHEN uqs.id IS NULL THEN 1 -- Unseen questions first
          WHEN uqs.status = 'incorrect' THEN 2 -- Incorrect questions next
          ELSE 3 -- Other statuses last
        END,
        RANDOM()
      LIMIT v_question_pool
    ) LOOP
      v_question_ids := v_question_ids || v_question.id;
    END LOOP;
  END IF;
  
  -- Get actual number of questions found
  v_question_count := array_length(v_question_ids, 1);
  
  IF v_question_count IS NULL OR v_question_count = 0 THEN
    -- No questions found, delete test and return error
    DELETE FROM tests WHERE id = v_test_id;
    RETURN json_build_object(
      'success', false,
      'message', 'Could not create test: No questions available matching criteria'
    );
  END IF;
  
  -- Link questions to test
  INSERT INTO test_questions (
    test_id,
    question_id,
    question_order
  )
  SELECT 
    v_test_id,
    q,
    row_number() OVER ()
  FROM 
    unnest(v_question_ids) AS q;
  
  -- Update test with question count
  UPDATE tests
  SET question_count = v_question_count
  WHERE id = v_test_id;
  
  -- Create CAT session
  INSERT INTO cat_sessions (
    test_id,
    user_id,
    initial_ability,
    current_ability,
    passing_standard,
    min_questions,
    max_questions
  ) VALUES (
    v_test_id,
    v_user_id,
    v_initial_ability,
    v_initial_ability,
    p_passing_standard,
    p_min_questions,
    LEAST(p_max_questions, v_question_count)
  ) RETURNING id INTO v_cat_session_id;
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'test_id', v_test_id,
    'cat_session_id', v_cat_session_id,
    'question_count', v_question_count,
    'message', 'CAT test created successfully'
  );
END;
$$;
