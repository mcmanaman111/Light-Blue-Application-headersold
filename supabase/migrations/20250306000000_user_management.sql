/*
  User Management System
  
  This migration creates tables for user management that extend Supabase's built-in auth:
  - roles: Defines user roles (admin, team, user, test, trial)
  - user_profiles: Extends auth.users with additional profile information
  
  Note: Supabase already has auth.users table that handles core authentication.
  These tables extend that functionality rather than replacing it.
*/

-- Create roles table
CREATE TABLE roles (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  permissions JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on roles
CREATE TRIGGER update_roles_updated_at
  BEFORE UPDATE ON roles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on roles
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

-- Create extended user profiles table
-- This extends the default auth.users table with additional fields
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username VARCHAR(255) UNIQUE,
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  role_id INTEGER REFERENCES roles(id) ON DELETE SET NULL,
  subscription_status VARCHAR(50) DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,
  nursing_program VARCHAR(255),
  graduation_date DATE,
  exam_date DATE,
  avatar_url TEXT,
  last_login_at TIMESTAMPTZ,
  login_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create trigger for updated_at on user_profiles
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create indices
CREATE INDEX idx_user_profiles_role_id ON user_profiles(role_id);
CREATE INDEX idx_user_profiles_subscription_status ON user_profiles(subscription_status);

-- Create RLS policies

-- Roles policies (admin only for write, public for read)
CREATE POLICY "Anyone can view roles"
  ON roles FOR SELECT
  USING (true);

CREATE POLICY "Only admins can modify roles"
  ON roles FOR ALL
  USING (
    auth.uid() IN (
      SELECT up.id FROM user_profiles up WHERE up.role_id IN (SELECT id FROM roles WHERE name = 'admin')
    )
  );

-- User profiles policies (user specific + admin)
CREATE POLICY "Users can view their own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON user_profiles FOR SELECT
  USING (
    auth.uid() IN (
      SELECT up.id FROM user_profiles up WHERE up.role_id IN (SELECT id FROM roles WHERE name = 'admin')
    )
  );

CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND 
    -- Prevent users from changing their own role
    (role_id IS NULL OR role_id = (SELECT role_id FROM user_profiles WHERE id = auth.uid()))
  );

CREATE POLICY "Admins can modify all profiles"
  ON user_profiles FOR ALL
  USING (
    auth.uid() IN (
      SELECT up.id FROM user_profiles up WHERE up.role_id IN (SELECT id FROM roles WHERE name = 'admin')
    )
  );

-- Create function to create a profile when a user signs up
CREATE OR REPLACE FUNCTION handle_new_user() 
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Get the username from the email (part before @)
  -- Or use a random string if no email
  DECLARE
    v_username TEXT;
    v_role_id INTEGER;
  BEGIN
    -- Get default user role
    SELECT id INTO v_role_id FROM roles WHERE name = 'user';
    
    -- Create username from email or a random string
    IF NEW.email IS NOT NULL THEN
      v_username := SPLIT_PART(NEW.email, '@', 1);
    ELSE
      v_username := 'user_' || FLOOR(RANDOM() * 1000000)::TEXT;
    END IF;
    
    -- Check for username conflicts and append numbers if needed
    WHILE EXISTS (SELECT 1 FROM user_profiles WHERE username = v_username) LOOP
      v_username := v_username || FLOOR(RANDOM() * 10)::TEXT;
    END LOOP;
    
    -- Insert new user profile
    INSERT INTO user_profiles (
      id,
      username,
      role_id,
      first_name,
      last_name,
      last_login_at,
      created_at,
      updated_at
    ) VALUES (
      NEW.id,
      v_username,
      v_role_id,
      NEW.raw_user_meta_data->>'first_name',
      NEW.raw_user_meta_data->>'last_name',
      now(),
      now(),
      now()
    );
    
    RETURN NEW;
  END;
END;
$$;

-- Create trigger for creating profile when user signs up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Create function to update login information
CREATE OR REPLACE FUNCTION handle_user_login() 
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE user_profiles
  SET 
    last_login_at = now(),
    login_count = login_count + 1
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$;

-- Create trigger for updating login info
CREATE TRIGGER on_auth_user_login
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  WHEN (OLD.last_sign_in_at IS DISTINCT FROM NEW.last_sign_in_at)
  EXECUTE FUNCTION handle_user_login();

-- Insert default roles
INSERT INTO roles (name, description, permissions) VALUES
('admin', 'Administrator with full access to all features', '{"can_manage_users":true, "can_manage_content":true, "can_manage_system":true}'::jsonb),
('team', 'Team member with access to content management', '{"can_manage_content":true}'::jsonb),
('user', 'Regular user with standard access', '{}'::jsonb),
('test', 'Test user for development purposes', '{}'::jsonb),
('trial', 'Trial user with limited access', '{"is_trial":true}'::jsonb);
