-- ============================================================
-- SUPABASE RLS (Row Level Security) POLICIES
-- ============================================================
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- These policies ensure data security at the database level.
-- Even if someone gets the anon key, they can't access/modify
-- other users' data.
-- ============================================================

-- ============================================================
-- 1. PROFILES TABLE
-- ============================================================

-- Enable RLS on profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Update role check constraint to support pending approval states
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('folk_boy', 'residency', 'preacher', 'admin', 'pending_folk_boy', 'pending_residency'));

-- Add preacher_code column if it does not exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS preacher_code TEXT;


-- Users can read their own profile
CREATE POLICY "Users can read own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile (but NOT the role field)
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    -- Prevent role escalation: role must stay the same
    AND role = (SELECT role FROM profiles WHERE id = auth.uid())
  );

-- Users can insert their own profile (on signup)
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Preachers can read profiles of their folk boys/residents
CREATE POLICY "Preachers can read their folk boys" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'preacher'
      AND profiles.preacher_id = p.id
    )
  );

-- Preachers can update their folk boys' profiles (e.g., role promotion)
CREATE POLICY "Preachers can update their folk boys" ON profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'preacher'
      AND profiles.preacher_id = p.id
    )
  );

-- Admin can read all profiles
CREATE POLICY "Admin can read all profiles" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admin can update all profiles
CREATE POLICY "Admin can update all profiles" ON profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admin can insert profiles (for creating preacher accounts)
CREATE POLICY "Admin can insert profiles" ON profiles
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Folk boys can read their preacher's profile (for name/photo)
CREATE POLICY "Folk boys can read their preacher" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.preacher_id = profiles.id
    )
  );

-- ============================================================
-- 2. UPDATES TABLE
-- ============================================================

-- Enable RLS on updates table
ALTER TABLE updates ENABLE ROW LEVEL SECURITY;

-- Users can read their own updates
CREATE POLICY "Users can read own updates" ON updates
  FOR SELECT USING (auth.uid()::text = worker_id);

-- Users can insert their own updates
CREATE POLICY "Users can insert own updates" ON updates
  FOR INSERT WITH CHECK (auth.uid()::text = worker_id);

-- Users can update their own updates
CREATE POLICY "Users can update own updates" ON updates
  FOR UPDATE USING (auth.uid()::text = worker_id);

-- Users can delete their own updates
CREATE POLICY "Users can delete own updates" ON updates
  FOR DELETE USING (auth.uid()::text = worker_id);

-- Preachers can read updates of their folk boys
CREATE POLICY "Preachers can read folk boy updates" ON updates
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'preacher'
      AND updates.worker_id IN (
        SELECT id::text FROM profiles WHERE preacher_id = p.id
      )
    )
  );

-- Preachers can insert updates for their folk boys (e.g., lock signals)
CREATE POLICY "Preachers can insert folk boy updates" ON updates
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'preacher'
      AND updates.worker_id IN (
        SELECT id::text FROM profiles WHERE preacher_id = p.id
      )
    )
  );

-- Preachers can update their folk boys' updates
CREATE POLICY "Preachers can update folk boy updates" ON updates
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'preacher'
      AND updates.worker_id IN (
        SELECT id::text FROM profiles WHERE preacher_id = p.id
      )
    )
  );

-- Preachers can delete their folk boys' updates
CREATE POLICY "Preachers can delete folk boy updates" ON updates
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'preacher'
      AND updates.worker_id IN (
        SELECT id::text FROM profiles WHERE preacher_id = p.id
      )
    )
  );

-- Admin can do everything on updates
CREATE POLICY "Admin full access on updates" ON updates
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- 3. ANNOUNCEMENTS TABLE
-- ============================================================

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- Everyone can read announcements
CREATE POLICY "Everyone can read announcements" ON announcements
  FOR SELECT USING (true);

-- Only preachers and admin can create announcements
CREATE POLICY "Preachers and admin can create announcements" ON announcements
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('preacher', 'admin')
    )
  );

-- Only preachers and admin can update/delete announcements
CREATE POLICY "Preachers and admin can modify announcements" ON announcements
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('preacher', 'admin')
    )
  );

CREATE POLICY "Preachers and admin can delete announcements" ON announcements
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('preacher', 'admin')
    )
  );

-- ============================================================
-- 4. ONLINE_ANNOUNCEMENTS TABLE
-- ============================================================

ALTER TABLE online_announcements ENABLE ROW LEVEL SECURITY;

-- Everyone can read online announcements
CREATE POLICY "Everyone can read online announcements" ON online_announcements
  FOR SELECT USING (true);

-- Only preachers and admin can manage online announcements
CREATE POLICY "Preachers and admin manage online announcements" ON online_announcements
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('preacher', 'admin')
    )
  );

-- ============================================================
-- 5. PREVENT ROLE ESCALATION (CRITICAL!)
-- ============================================================
-- This function prevents users from changing their own role
-- to 'admin' or 'preacher' through the API.

CREATE OR REPLACE FUNCTION prevent_role_escalation()
RETURNS TRIGGER AS $$
BEGIN
  -- If the user is changing their own role
  IF NEW.id = auth.uid() THEN
    -- Only allow downgrade or same role, not escalation
    IF NEW.role != OLD.role THEN
      -- Block self role changes entirely
      RAISE EXCEPTION 'Cannot change your own role';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS prevent_role_escalation_trigger ON profiles;

-- Create trigger
CREATE TRIGGER prevent_role_escalation_trigger
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  WHEN (OLD.role IS DISTINCT FROM NEW.role)
  EXECUTE FUNCTION prevent_role_escalation();

-- ============================================================
-- 6. AUTH USER TO PUBLIC PROFILES SYNC TRIGGER (CRITICAL!)
-- ============================================================
-- Automatically create/update a user's profile upon signup.
-- Copies name, role, preacher_id and whatsapp_number from raw_user_meta_data.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, role, preacher_id, whatsapp_number)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'pending_folk_boy'),
    (NEW.raw_user_meta_data->>'preacher_id')::uuid,
    NEW.raw_user_meta_data->>'whatsapp_number'
  )
  ON CONFLICT (id) DO UPDATE
  SET
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    preacher_id = EXCLUDED.preacher_id,
    whatsapp_number = EXCLUDED.whatsapp_number;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: The trigger on auth.users calling handle_new_user() is created by default in Supabase.
-- But if it is missing, you can create it with:
-- CREATE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- IMPORTANT NOTES:
-- ============================================================
-- 1. Run this SQL in your Supabase Dashboard > SQL Editor
-- 2. If you get "policy already exists" errors, drop existing
--    policies first with: DROP POLICY "policy_name" ON table_name;
-- 3. Test each policy by trying to access data as different roles
-- 4. The anon key is safe to have in the APK ONLY when these
--    RLS policies are properly configured!
-- ============================================================

