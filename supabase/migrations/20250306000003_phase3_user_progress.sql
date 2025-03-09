/*
  Phase 3: User Progress Tracking
  
  This migration creates tables for tracking user progress:
  - user_profiles: Extended information about users
  - user_statistics: Performance statistics for users by topic/subtopic
  - study_plans: Personalized study plans for users
  - study_plan_items: Individual tasks within a study plan
  
  It also sets up Row Level Security (RLS) policies to protect data access.
*/

-- Create user_profiles table
CREATE TABLE user_profiles (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  nursing_program VARCHAR(255),
  graduation_date DATE,
  exam_date DATE,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Create trigger for updated_at on user_profiles
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create user_statistics table
CREATE TABLE user_statistics (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  topic VARCHAR(255) NOT NULL,
  sub_topic VARCHAR(255),
  correct_count INTEGER NOT NULL DEFAULT 0,
  total_count INTEGER NOT NULL DEFAULT 0,
  average_time_seconds NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, topic, sub_topic)
);

-- Create trigger for updated_at on user_statistics
CREATE TRIGGER update_user_statistics_updated_at
  BEFORE UPDATE ON user_statistics
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on user_statistics
ALTER TABLE user_statistics ENABLE ROW LEVEL SECURITY;

-- Create study_plans table
CREATE TABLE study_plans (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on study_plans
CREATE TRIGGER update_study_plans_updated_at
  BEFORE UPDATE ON study_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on study_plans
ALTER TABLE study_plans ENABLE ROW LEVEL SECURITY;

-- Create study_plan_items table
CREATE TABLE study_plan_items (
  id SERIAL PRIMARY KEY,
  study_plan_id INTEGER REFERENCES study_plans(id) ON DELETE CASCADE,
  due_date DATE NOT NULL,
  topic VARCHAR(255) NOT NULL,
  sub_topic VARCHAR(255),
  activity_type VARCHAR(255) NOT NULL, -- Study, Practice, Review, etc.
  description TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on study_plan_items
CREATE TRIGGER update_study_plan_items_updated_at
  BEFORE UPDATE ON study_plan_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on study_plan_items
ALTER TABLE study_plan_items ENABLE ROW LEVEL SECURITY;

-- Create indices
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_statistics_user_id ON user_statistics(user_id);
CREATE INDEX idx_user_statistics_topic ON user_statistics(topic);
CREATE INDEX idx_user_statistics_sub_topic ON user_statistics(sub_topic);
CREATE INDEX idx_study_plans_user_id ON study_plans(user_id);
CREATE INDEX idx_study_plan_items_study_plan_id ON study_plan_items(study_plan_id);
CREATE INDEX idx_study_plan_items_due_date ON study_plan_items(due_date);
CREATE INDEX idx_study_plan_items_completed ON study_plan_items(completed);

-- Create RLS policies

-- User profiles policies (user specific)
CREATE POLICY "Users can view their own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own profile"
  ON user_profiles FOR DELETE
  USING (auth.uid() = user_id);

-- User statistics policies (user specific)
CREATE POLICY "Users can view their own statistics"
  ON user_statistics FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own statistics"
  ON user_statistics FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own statistics"
  ON user_statistics FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own statistics"
  ON user_statistics FOR DELETE
  USING (auth.uid() = user_id);

-- Study plans policies (user specific)
CREATE POLICY "Users can view their own study plans"
  ON study_plans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own study plans"
  ON study_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own study plans"
  ON study_plans FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own study plans"
  ON study_plans FOR DELETE
  USING (auth.uid() = user_id);

-- Study plan items policies
CREATE POLICY "Users can view items in their own study plans"
  ON study_plan_items FOR SELECT
  USING (
    study_plan_id IN (
      SELECT id FROM study_plans WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert items in their own study plans"
  ON study_plan_items FOR INSERT
  WITH CHECK (
    study_plan_id IN (
      SELECT id FROM study_plans WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update items in their own study plans"
  ON study_plan_items FOR UPDATE
  USING (
    study_plan_id IN (
      SELECT id FROM study_plans WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    study_plan_id IN (
      SELECT id FROM study_plans WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete items in their own study plans"
  ON study_plan_items FOR DELETE
  USING (
    study_plan_id IN (
      SELECT id FROM study_plans WHERE user_id = auth.uid()
    )
  );

-- Create functions for user progress tracking

-- Function to update user statistics after a test result
CREATE OR REPLACE FUNCTION update_user_statistics() 
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_topic TEXT;
  v_sub_topic TEXT;
  v_time_spent INTEGER;
BEGIN
  -- Get question topic and sub_topic
  SELECT 
    topic, 
    sub_topic
  INTO 
    v_topic, 
    v_sub_topic
  FROM 
    questions
  WHERE 
    id = NEW.question_id;

  -- Update or insert into user_statistics for the topic level
  INSERT INTO user_statistics (
    user_id,
    topic,
    sub_topic,
    correct_count,
    total_count,
    average_time_seconds
  ) VALUES (
    NEW.user_id,
    v_topic,
    NULL,
    CASE WHEN NEW.is_correct THEN 1 ELSE 0 END,
    1,
    NEW.time_spent_seconds
  )
  ON CONFLICT (user_id, topic, COALESCE(sub_topic, ''))
  DO UPDATE SET
    correct_count = user_statistics.correct_count + CASE WHEN NEW.is_correct THEN 1 ELSE 0 END,
    total_count = user_statistics.total_count + 1,
    average_time_seconds = (user_statistics.average_time_seconds * user_statistics.total_count + NEW.time_spent_seconds) / (user_statistics.total_count + 1);

  -- Update or insert into user_statistics for the sub_topic level
  IF v_sub_topic IS NOT NULL THEN
    INSERT INTO user_statistics (
      user_id,
      topic,
      sub_topic,
      correct_count,
      total_count,
      average_time_seconds
    ) VALUES (
      NEW.user_id,
      v_topic,
      v_sub_topic,
      CASE WHEN NEW.is_correct THEN 1 ELSE 0 END,
      1,
      NEW.time_spent_seconds
    )
    ON CONFLICT (user_id, topic, COALESCE(sub_topic, ''))
    DO UPDATE SET
      correct_count = user_statistics.correct_count + CASE WHEN NEW.is_correct THEN 1 ELSE 0 END,
      total_count = user_statistics.total_count + 1,
      average_time_seconds = (user_statistics.average_time_seconds * user_statistics.total_count + NEW.time_spent_seconds) / (user_statistics.total_count + 1);
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger to update statistics when a test result is added
CREATE TRIGGER update_statistics_on_test_result
  AFTER INSERT ON test_results
  FOR EACH ROW
  EXECUTE FUNCTION update_user_statistics();

-- Function to generate a study plan based on user statistics
CREATE OR REPLACE FUNCTION generate_study_plan(
  p_user_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_start_date DATE,
  p_end_date DATE,
  p_daily_hours INTEGER DEFAULT 4
) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_study_plan_id INTEGER;
  v_days_until_exam INTEGER;
  v_topic RECORD;
  v_subtopic RECORD;
  v_current_date DATE;
  v_total_topics INTEGER;
  v_topic_duration INTEGER;
  v_description TEXT;
  v_i INTEGER;
BEGIN
  -- Ensure the user_id matches the authenticated user
  IF auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'You can only create study plans for yourself';
  END IF;

  -- Calculate days until exam
  v_days_until_exam := p_end_date - p_start_date;
  
  -- Ensure there are enough days
  IF v_days_until_exam < 7 THEN
    RAISE EXCEPTION 'Study plan requires at least 7 days';
  END IF;

  -- Count total topics
  SELECT COUNT(*) INTO v_total_topics FROM topics;
  
  IF v_total_topics = 0 THEN
    RAISE EXCEPTION 'No topics found to create study plan';
  END IF;

  -- Create the study plan
  INSERT INTO study_plans (
    user_id,
    title,
    description,
    start_date,
    end_date
  ) VALUES (
    p_user_id,
    p_title,
    p_description,
    p_start_date,
    p_end_date
  ) RETURNING id INTO v_study_plan_id;

  -- Distribute topics across the available days
  v_current_date := p_start_date;
  
  -- First pass: Add overview for each topic
  FOR v_topic IN (
    SELECT 
      t.id, 
      t.name, 
      COALESCE(us.correct_count, 0) AS correct_count,
      COALESCE(us.total_count, 0) AS total_count
    FROM 
      topics t
    LEFT JOIN 
      user_statistics us ON t.name = us.topic AND us.user_id = p_user_id AND us.sub_topic IS NULL
    ORDER BY 
      CASE 
        WHEN us.total_count = 0 THEN 999 -- Topics with no attempts go first
        ELSE us.correct_count::float / NULLIF(us.total_count, 0) -- Then by success rate
      END ASC
  ) LOOP
    -- Create overview study task for each topic
    INSERT INTO study_plan_items (
      study_plan_id,
      due_date,
      topic,
      activity_type,
      description,
      duration_minutes
    ) VALUES (
      v_study_plan_id,
      v_current_date,
      v_topic.name,
      'Study',
      'Overview of ' || v_topic.name,
      120 -- 2 hours
    );
    
    -- Move to next day every 2 topics
    IF v_current_date < p_end_date - 2 THEN -- Leave a few days at the end for review
      v_current_date := v_current_date + (v_topic.id % 2)::integer; -- Advance day every other topic
    END IF;
  END LOOP;

  -- Second pass: Practice for each subtopic
  v_current_date := p_start_date + 2; -- Start subtopics a few days in
  
  FOR v_subtopic IN (
    SELECT 
      s.id,
      s.name AS subtopic_name,
      t.name AS topic_name,
      COALESCE(us.correct_count, 0) AS correct_count,
      COALESCE(us.total_count, 0) AS total_count
    FROM 
      subtopics s
    JOIN 
      topics t ON s.topic_id = t.id
    LEFT JOIN 
      user_statistics us ON t.name = us.topic AND s.name = us.sub_topic AND us.user_id = p_user_id
    ORDER BY 
      CASE 
        WHEN us.total_count = 0 THEN 999 -- Subtopics with no attempts go first
        ELSE us.correct_count::float / NULLIF(us.total_count, 0) -- Then by success rate
      END ASC
  ) LOOP
    -- Create practice task for the subtopic
    INSERT INTO study_plan_items (
      study_plan_id,
      due_date,
      topic,
      sub_topic,
      activity_type,
      description,
      duration_minutes
    ) VALUES (
      v_study_plan_id,
      v_current_date,
      v_subtopic.topic_name,
      v_subtopic.subtopic_name,
      'Practice',
      'Practice questions on ' || v_subtopic.subtopic_name,
      90 -- 1.5 hours
    );
    
    -- Move to next day every 3 subtopics
    IF v_current_date < p_end_date - 5 THEN -- Leave a few days at the end for review
      v_current_date := v_current_date + (v_subtopic.id % 3)::integer; -- Advance day every third subtopic
    END IF;
  END LOOP;

  -- Last 5 days: Add review tasks and practice tests
  v_current_date := p_end_date - 5;
  
  -- Add simulated exams for the last few days
  FOR v_i IN 0..2 LOOP
    INSERT INTO study_plan_items (
      study_plan_id,
      due_date,
      topic,
      activity_type,
      description,
      duration_minutes
    ) VALUES (
      v_study_plan_id,
      p_end_date - (5 - v_i),
      'NCLEX Simulation',
      'Test',
      'Take a full simulated NCLEX exam',
      360 -- 6 hours
    );
  END LOOP;
  
  -- Add final review
  INSERT INTO study_plan_items (
    study_plan_id,
    due_date,
    topic,
    activity_type,
    description,
    duration_minutes
  ) VALUES (
    v_study_plan_id,
    p_end_date - 1,
    'Final Review',
    'Review',
    'Final review of weak areas before the exam',
    240 -- 4 hours
  );

  RETURN v_study_plan_id;
END;
$$;
