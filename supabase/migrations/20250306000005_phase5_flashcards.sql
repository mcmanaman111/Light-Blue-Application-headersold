/*
  Phase 5: Flashcards System
  
  This migration creates tables for flashcards with spaced repetition:
  - flashcard_decks: Collections of flashcards created by users
  - flashcards: Individual flashcards for study
  - flashcard_progress: Tracks user progress with individual flashcards
  
  It also implements functions for spaced repetition scheduling.
*/

-- Create flashcard_decks table
CREATE TABLE flashcard_decks (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  topic VARCHAR(255),
  sub_topic VARCHAR(255),
  is_public BOOLEAN DEFAULT false,
  card_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on flashcard_decks
CREATE TRIGGER update_flashcard_decks_updated_at
  BEFORE UPDATE ON flashcard_decks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on flashcard_decks
ALTER TABLE flashcard_decks ENABLE ROW LEVEL SECURITY;

-- Create flashcards table
CREATE TABLE flashcards (
  id SERIAL PRIMARY KEY,
  deck_id INTEGER REFERENCES flashcard_decks(id) ON DELETE CASCADE,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  topic VARCHAR(255),
  sub_topic VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on flashcards
CREATE TRIGGER update_flashcards_updated_at
  BEFORE UPDATE ON flashcards
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on flashcards
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;

-- Create flashcard_progress table
CREATE TABLE flashcard_progress (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  flashcard_id INTEGER REFERENCES flashcards(id) ON DELETE CASCADE,
  ease_factor NUMERIC(4,3) DEFAULT 2.5,
  interval_days INTEGER DEFAULT 1,
  last_reviewed TIMESTAMPTZ,
  next_review TIMESTAMPTZ,
  review_count INTEGER DEFAULT 0,
  last_performance SMALLINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, flashcard_id)
);

-- Create trigger for updated_at on flashcard_progress
CREATE TRIGGER update_flashcard_progress_updated_at
  BEFORE UPDATE ON flashcard_progress
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on flashcard_progress
ALTER TABLE flashcard_progress ENABLE ROW LEVEL SECURITY;

-- Create indices
CREATE INDEX idx_flashcard_decks_user_id ON flashcard_decks(user_id);
CREATE INDEX idx_flashcard_decks_is_public ON flashcard_decks(is_public);
CREATE INDEX idx_flashcards_deck_id ON flashcards(deck_id);
CREATE INDEX idx_flashcards_topic ON flashcards(topic);
CREATE INDEX idx_flashcards_sub_topic ON flashcards(sub_topic);
CREATE INDEX idx_flashcard_progress_user_id ON flashcard_progress(user_id);
CREATE INDEX idx_flashcard_progress_flashcard_id ON flashcard_progress(flashcard_id);
CREATE INDEX idx_flashcard_progress_next_review ON flashcard_progress(next_review);

-- Create RLS policies

-- Flashcard decks policies (user specific + public access)
CREATE POLICY "Users can view their own flashcard decks"
  ON flashcard_decks FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view public flashcard decks"
  ON flashcard_decks FOR SELECT
  USING (is_public = true);

CREATE POLICY "Users can insert their own flashcard decks"
  ON flashcard_decks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own flashcard decks"
  ON flashcard_decks FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own flashcard decks"
  ON flashcard_decks FOR DELETE
  USING (auth.uid() = user_id);

-- Flashcards policies
CREATE POLICY "Users can view flashcards in their own decks"
  ON flashcards FOR SELECT
  USING (
    deck_id IN (
      SELECT id FROM flashcard_decks WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view flashcards in public decks"
  ON flashcards FOR SELECT
  USING (
    deck_id IN (
      SELECT id FROM flashcard_decks WHERE is_public = true
    )
  );

CREATE POLICY "Users can insert flashcards in their own decks"
  ON flashcards FOR INSERT
  WITH CHECK (
    deck_id IN (
      SELECT id FROM flashcard_decks WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update flashcards in their own decks"
  ON flashcards FOR UPDATE
  USING (
    deck_id IN (
      SELECT id FROM flashcard_decks WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    deck_id IN (
      SELECT id FROM flashcard_decks WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete flashcards in their own decks"
  ON flashcards FOR DELETE
  USING (
    deck_id IN (
      SELECT id FROM flashcard_decks WHERE user_id = auth.uid()
    )
  );

-- Flashcard progress policies (user specific)
CREATE POLICY "Users can view their own flashcard progress"
  ON flashcard_progress FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own flashcard progress"
  ON flashcard_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own flashcard progress"
  ON flashcard_progress FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own flashcard progress"
  ON flashcard_progress FOR DELETE
  USING (auth.uid() = user_id);

-- Create function to update card_count when flashcards are added or deleted
CREATE OR REPLACE FUNCTION update_flashcard_deck_count() 
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment card count
    UPDATE flashcard_decks 
    SET card_count = card_count + 1
    WHERE id = NEW.deck_id;
    RETURN NEW;
    
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement card count
    UPDATE flashcard_decks 
    SET card_count = card_count - 1
    WHERE id = OLD.deck_id AND card_count > 0;
    RETURN OLD;
  END IF;
  
  RETURN NULL;
END;
$$;

-- Create triggers for updating card count
CREATE TRIGGER increment_flashcard_count
  AFTER INSERT ON flashcards
  FOR EACH ROW
  EXECUTE FUNCTION update_flashcard_deck_count();

CREATE TRIGGER decrement_flashcard_count
  AFTER DELETE ON flashcards
  FOR EACH ROW
  EXECUTE FUNCTION update_flashcard_deck_count();

-- Function to duplicate a deck (make a copy of someone else's deck)
CREATE OR REPLACE FUNCTION duplicate_flashcard_deck(
  p_source_deck_id INTEGER,
  p_new_title TEXT DEFAULT NULL
) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_source_deck RECORD;
  v_new_deck_id INTEGER;
  v_card RECORD;
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  
  -- Check if source deck exists and is either public or belongs to the user
  SELECT * INTO v_source_deck
  FROM flashcard_decks
  WHERE 
    id = p_source_deck_id 
    AND (is_public = true OR user_id = v_user_id);
    
  IF v_source_deck.id IS NULL THEN
    RAISE EXCEPTION 'Deck not found or not accessible';
  END IF;
  
  -- Create new deck
  INSERT INTO flashcard_decks (
    user_id,
    title,
    description,
    topic,
    sub_topic,
    is_public,
    card_count
  ) VALUES (
    v_user_id,
    COALESCE(p_new_title, v_source_deck.title || ' (Copy)'),
    v_source_deck.description,
    v_source_deck.topic,
    v_source_deck.sub_topic,
    false, -- New copy is private by default
    0 -- Will be updated automatically by triggers
  ) RETURNING id INTO v_new_deck_id;
  
  -- Copy all flashcards from source deck
  FOR v_card IN (
    SELECT * FROM flashcards WHERE deck_id = p_source_deck_id
  ) LOOP
    INSERT INTO flashcards (
      deck_id,
      front,
      back,
      topic,
      sub_topic
    ) VALUES (
      v_new_deck_id,
      v_card.front,
      v_card.back,
      v_card.topic,
      v_card.sub_topic
    );
  END LOOP;
  
  RETURN v_new_deck_id;
END;
$$;

-- Function to implement spaced repetition algorithm (SuperMemo SM-2)
CREATE OR REPLACE FUNCTION update_flashcard_spaced_repetition(
  p_flashcard_id INTEGER,
  p_performance INTEGER -- 0-5 scale (0=failed, 5=perfect)
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_progress_id INTEGER;
  v_ease_factor NUMERIC(4,3);
  v_interval_days INTEGER;
  v_review_count INTEGER;
  v_next_review TIMESTAMPTZ;
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  
  -- Get or create progress record
  SELECT id, ease_factor, interval_days, review_count
  INTO v_progress_id, v_ease_factor, v_interval_days, v_review_count
  FROM flashcard_progress
  WHERE user_id = v_user_id AND flashcard_id = p_flashcard_id;
  
  -- If no progress record exists, create one
  IF v_progress_id IS NULL THEN
    INSERT INTO flashcard_progress (
      user_id,
      flashcard_id,
      ease_factor,
      interval_days,
      last_reviewed,
      next_review,
      review_count,
      last_performance
    ) VALUES (
      v_user_id,
      p_flashcard_id,
      2.5, -- Default ease factor
      1, -- Default interval
      now(),
      now() + INTERVAL '1 day',
      1,
      p_performance
    ) RETURNING 
      id, 
      ease_factor, 
      interval_days, 
      review_count, 
      next_review
    INTO 
      v_progress_id, 
      v_ease_factor, 
      v_interval_days, 
      v_review_count,
      v_next_review;
  ELSE
    -- Implement SuperMemo SM-2 algorithm
    -- Calculate new ease factor: EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
    v_ease_factor := v_ease_factor + (0.1 - (5 - p_performance) * (0.08 + (5 - p_performance) * 0.02));
    
    -- Ensure ease factor doesn't go below 1.3
    IF v_ease_factor < 1.3 THEN
      v_ease_factor := 1.3;
    END IF;
    
    -- Calculate new interval
    IF p_performance < 3 THEN
      -- If performance is poor, reset to 1 day
      v_interval_days := 1;
    ELSE
      -- Otherwise, calculate new interval based on current interval and ease factor
      IF v_review_count = 0 THEN
        v_interval_days := 1;
      ELSIF v_review_count = 1 THEN
        v_interval_days := 6;
      ELSE
        v_interval_days := ROUND(v_interval_days * v_ease_factor);
      END IF;
    END IF;
    
    -- Update progress record
    UPDATE flashcard_progress
    SET 
      ease_factor = v_ease_factor,
      interval_days = v_interval_days,
      last_reviewed = now(),
      next_review = now() + (v_interval_days || ' days')::INTERVAL,
      review_count = review_count + 1,
      last_performance = p_performance
    WHERE 
      id = v_progress_id
    RETURNING next_review INTO v_next_review;
  END IF;
  
  -- Return updated values
  RETURN json_build_object(
    'flashcard_id', p_flashcard_id,
    'ease_factor', v_ease_factor,
    'interval_days', v_interval_days,
    'review_count', v_review_count,
    'next_review', v_next_review
  );
END;
$$;

-- Function to get due flashcards for review
CREATE OR REPLACE FUNCTION get_due_flashcards(
  p_limit INTEGER DEFAULT 20,
  p_topics TEXT[] DEFAULT NULL,
  p_decks INTEGER[] DEFAULT NULL
) RETURNS TABLE (
  id INTEGER,
  deck_id INTEGER,
  deck_title TEXT,
  front TEXT,
  back TEXT,
  topic TEXT,
  sub_topic TEXT,
  ease_factor NUMERIC,
  interval_days INTEGER,
  review_count INTEGER,
  last_performance INTEGER
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT 
    f.id,
    f.deck_id,
    fd.title AS deck_title,
    f.front,
    f.back,
    f.topic,
    f.sub_topic,
    fp.ease_factor,
    fp.interval_days,
    fp.review_count,
    fp.last_performance
  FROM 
    flashcards f
  JOIN 
    flashcard_decks fd ON f.deck_id = fd.id
  LEFT JOIN 
    flashcard_progress fp ON f.id = fp.flashcard_id AND fp.user_id = auth.uid()
  WHERE 
    -- Only include cards that are due or new
    (
      fp.id IS NULL OR 
      fp.next_review <= now()
    )
    -- Only include cards from decks the user owns or public decks
    AND (
      fd.user_id = auth.uid() OR 
      fd.is_public = true
    )
    -- Filter by topics if specified
    AND (
      p_topics IS NULL OR 
      f.topic = ANY(p_topics)
    )
    -- Filter by decks if specified
    AND (
      p_decks IS NULL OR 
      f.deck_id = ANY(p_decks)
    )
  ORDER BY 
    -- Order by:
    -- 1. User's own cards before public cards
    fd.user_id = auth.uid() DESC,
    -- 2. New cards (no progress) first
    fp.id IS NULL DESC,
    -- 3. Cards with lower ease factor (more difficult) first
    COALESCE(fp.ease_factor, 2.5) ASC,
    -- 4. Sort by due date for cards with progress
    COALESCE(fp.next_review, now()) ASC
  LIMIT p_limit;
END;
$$;

-- Create view for flashcard statistics
CREATE OR REPLACE VIEW user_flashcard_statistics AS
SELECT
  fp.user_id,
  f.topic,
  f.sub_topic,
  COUNT(*) AS total_cards,
  SUM(CASE WHEN fp.id IS NOT NULL THEN 1 ELSE 0 END) AS reviewed_cards,
  SUM(CASE WHEN fp.review_count >= 3 AND fp.last_performance >= 4 THEN 1 ELSE 0 END) AS mastered_cards,
  ROUND(AVG(CASE WHEN fp.id IS NOT NULL THEN fp.ease_factor ELSE NULL END), 2) AS avg_ease_factor,
  ROUND(AVG(CASE WHEN fp.id IS NOT NULL THEN fp.interval_days ELSE NULL END), 0) AS avg_interval_days
FROM
  flashcards f
JOIN
  flashcard_decks fd ON f.deck_id = fd.id
CROSS JOIN
  auth.users u
LEFT JOIN
  flashcard_progress fp ON f.id = fp.flashcard_id AND u.id = fp.user_id
WHERE
  fd.user_id = u.id OR fd.is_public = true
GROUP BY
  fp.user_id, f.topic, f.sub_topic;
