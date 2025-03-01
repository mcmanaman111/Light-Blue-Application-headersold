/*
  # Update Notes Table RLS Policies

  1. Changes
    - Drop existing RLS policies
    - Create new policies with proper user_id handling
    - Add trigger for user_id on insert

  2. Security
    - Enable RLS
    - Add policies for CRUD operations
    - Automatically set user_id on insert
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert their own notes" ON notes;
DROP POLICY IF EXISTS "Users can view their own notes" ON notes;
DROP POLICY IF EXISTS "Users can update their own notes" ON notes;
DROP POLICY IF EXISTS "Users can delete their own notes" ON notes;

-- Create function to get authenticated user id
CREATE OR REPLACE FUNCTION get_auth_user_id()
RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT auth.uid();
$$;

-- Create trigger to automatically set user_id
CREATE OR REPLACE FUNCTION set_user_id()
RETURNS TRIGGER AS $$
BEGIN
  NEW.user_id = get_auth_user_id();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS set_user_id_trigger ON notes;

-- Create trigger
CREATE TRIGGER set_user_id_trigger
  BEFORE INSERT ON notes
  FOR EACH ROW
  EXECUTE FUNCTION set_user_id();

-- Create new policies
CREATE POLICY "Enable insert for authenticated users"
  ON notes
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable read access for users based on user_id"
  ON notes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Enable update for users based on user_id"
  ON notes
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Enable delete for users based on user_id"
  ON notes
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);