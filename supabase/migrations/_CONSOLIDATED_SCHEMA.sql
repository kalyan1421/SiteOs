-- ============================================================
-- SiteOS — CONSOLIDATED SCHEMA (migrations 001 → 051, in order)
-- Run ONCE in a fresh Supabase project: Dashboard → SQL Editor → paste → Run.
-- Excludes: DEMO_* (optional seed data), APPLY_*/FIX_* (redundant hotfix
-- bundles), HARD_RESET_* (destructive). Source: supabase/migrations/.
-- ============================================================

-- ============================================================
-- 001_initial_schema.sql
-- ============================================================
-- ============================================================
-- CLIVI MANAGEMENT - SUPABASE DATABASE SETUP
-- ============================================================
-- Run this SQL in your Supabase SQL Editor
-- Dashboard: https://supabase.com/dashboard/project/YOUR_PROJECT/sql
-- ============================================================

-- ============================================================
-- 1. USER PROFILES TABLE
-- ============================================================

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'site_manager' CHECK (role IN ('super_admin', 'admin', 'site_manager')),
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.user_profiles IS 'User profiles with role-based access control';

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. RLS POLICIES FOR USER_PROFILES
-- ============================================================

-- Policy: Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

-- Policy: Admins and Super Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
    ON public.user_profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Users can update their own profile (except role)
CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Policy: Super Admins can update any profile including role
CREATE POLICY "Super admins can update any profile"
    ON public.user_profiles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Policy: Super Admins can insert profiles
CREATE POLICY "Super admins can insert profiles"
    ON public.user_profiles FOR INSERT
    WITH CHECK (
        -- Allow insert for the user themselves (signup)
        auth.uid() = id
        OR
        -- Or by super_admin
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Policy: Super Admins can delete profiles
CREATE POLICY "Super admins can delete profiles"
    ON public.user_profiles FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- ============================================================
-- 3. PROJECTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    location TEXT,
    status TEXT DEFAULT 'planning' CHECK (status IN ('planning', 'in_progress', 'on_hold', 'completed', 'cancelled')),
    start_date DATE,
    end_date DATE,
    budget DECIMAL(15, 2),
    created_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. PROJECT ASSIGNMENTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.project_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    assigned_role TEXT DEFAULT 'member' CHECK (assigned_role IN ('manager', 'member', 'viewer')),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES public.user_profiles(id),
    UNIQUE(project_id, user_id)
);

-- Enable RLS
ALTER TABLE public.project_assignments ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 5. RLS POLICIES FOR PROJECTS
-- ============================================================

-- Policy: Super Admins and Admins can view all projects
CREATE POLICY "Admins can view all projects"
    ON public.projects FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Site Managers can only view assigned projects
CREATE POLICY "Site managers can view assigned projects"
    ON public.projects FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = projects.id AND user_id = auth.uid()
        )
    );

-- Policy: Admins can create projects
CREATE POLICY "Admins can create projects"
    ON public.projects FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Admins can update projects
CREATE POLICY "Admins can update projects"
    ON public.projects FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Super Admins can delete projects
CREATE POLICY "Super admins can delete projects"
    ON public.projects FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- ============================================================
-- 6. RLS POLICIES FOR PROJECT_ASSIGNMENTS
-- ============================================================

-- Policy: Users can view their own assignments
CREATE POLICY "Users can view own assignments"
    ON public.project_assignments FOR SELECT
    USING (user_id = auth.uid());

-- Policy: Admins can view all assignments
CREATE POLICY "Admins can view all assignments"
    ON public.project_assignments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Admins can manage assignments
CREATE POLICY "Admins can manage assignments"
    ON public.project_assignments FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- ============================================================
-- 7. STOCK/INVENTORY TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.stock_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    unit TEXT DEFAULT 'pieces',
    quantity DECIMAL(15, 2) DEFAULT 0,
    min_quantity DECIMAL(15, 2) DEFAULT 0,
    unit_price DECIMAL(15, 2),
    project_id UUID REFERENCES public.projects(id),
    created_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can manage all stock
CREATE POLICY "Admins can manage stock"
    ON public.stock_items FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Site managers can view project stock
CREATE POLICY "Site managers can view project stock"
    ON public.stock_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = stock_items.project_id AND user_id = auth.uid()
        )
    );

-- ============================================================
-- 8. LABOUR TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.labour (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    skill_type TEXT,
    daily_wage DECIMAL(10, 2),
    project_id UUID REFERENCES public.projects(id),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.labour ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can manage all labour
CREATE POLICY "Admins can manage labour"
    ON public.labour FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Site managers can view and manage project labour
CREATE POLICY "Site managers can manage project labour"
    ON public.labour FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = labour.project_id AND user_id = auth.uid()
        )
    );

-- ============================================================
-- 9. LABOUR ATTENDANCE TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.labour_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    labour_id UUID NOT NULL REFERENCES public.labour(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES public.projects(id),
    date DATE NOT NULL,
    status TEXT DEFAULT 'present' CHECK (status IN ('present', 'absent', 'half_day')),
    hours_worked DECIMAL(4, 2),
    notes TEXT,
    recorded_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(labour_id, date)
);

-- Enable RLS
ALTER TABLE public.labour_attendance ENABLE ROW LEVEL SECURITY;

-- Policy: Site managers can manage attendance for their projects
CREATE POLICY "Site managers can manage attendance"
    ON public.labour_attendance FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = labour_attendance.project_id AND user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- ============================================================
-- 10. MACHINERY TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.machinery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT,
    registration_number TEXT,
    status TEXT DEFAULT 'available' CHECK (status IN ('available', 'in_use', 'maintenance', 'retired')),
    hourly_rate DECIMAL(10, 2),
    current_project_id UUID REFERENCES public.projects(id),
    created_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.machinery ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can manage machinery
CREATE POLICY "Admins can manage machinery"
    ON public.machinery FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Site managers can view assigned machinery
CREATE POLICY "Site managers can view machinery"
    ON public.machinery FOR SELECT
    USING (
        current_project_id IS NULL
        OR
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = machinery.current_project_id AND user_id = auth.uid()
        )
    );

-- ============================================================
-- 11. BILLS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id),
    title TEXT NOT NULL,
    description TEXT,
    amount DECIMAL(15, 2) NOT NULL,
    bill_type TEXT DEFAULT 'expense' CHECK (bill_type IN ('expense', 'income', 'invoice')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'rejected')),
    bill_date DATE DEFAULT CURRENT_DATE,
    due_date DATE,
    vendor_name TEXT,
    receipt_url TEXT,
    created_by UUID REFERENCES public.user_profiles(id),
    approved_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can manage all bills
CREATE POLICY "Admins can manage bills"
    ON public.bills FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Site managers can view and create bills for their projects
CREATE POLICY "Site managers can manage project bills"
    ON public.bills FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = bills.project_id AND user_id = auth.uid()
        )
    );

-- ============================================================
-- 12. BLUEPRINTS/DOCUMENTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.blueprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id),
    title TEXT NOT NULL,
    description TEXT,
    file_url TEXT NOT NULL,
    file_type TEXT,
    file_size INTEGER,
    version TEXT DEFAULT '1.0',
    uploaded_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.blueprints ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can manage all blueprints
CREATE POLICY "Admins can manage blueprints"
    ON public.blueprints FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Policy: Site managers can view and upload blueprints for their projects
CREATE POLICY "Site managers can manage project blueprints"
    ON public.blueprints FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = blueprints.project_id AND user_id = auth.uid()
        )
    );

-- ============================================================
-- 13. DAILY REPORTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.daily_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id),
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    weather TEXT,
    work_summary TEXT,
    issues TEXT,
    tomorrow_plan TEXT,
    labour_count INTEGER DEFAULT 0,
    created_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, report_date)
);

-- Enable RLS
ALTER TABLE public.daily_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Site managers can manage reports for their projects
CREATE POLICY "Site managers can manage reports"
    ON public.daily_reports FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = daily_reports.project_id AND user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- ============================================================
-- 14. HELPER FUNCTIONS
-- ============================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON public.projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stock_items_updated_at
    BEFORE UPDATE ON public.stock_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_labour_updated_at
    BEFORE UPDATE ON public.labour
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_machinery_updated_at
    BEFORE UPDATE ON public.machinery
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bills_updated_at
    BEFORE UPDATE ON public.bills
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_blueprints_updated_at
    BEFORE UPDATE ON public.blueprints
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_reports_updated_at
    BEFORE UPDATE ON public.daily_reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 15. FUNCTION TO AUTO-CREATE USER PROFILE ON SIGNUP
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, role, full_name, created_at)
    VALUES (
        NEW.id,
        'site_manager',
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create profile when user signs up
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 16. STORAGE BUCKETS
-- ============================================================

-- Create storage buckets (run in SQL editor)
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('avatars', 'avatars', true),
    ('blueprints', 'blueprints', false),
    ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for avatars bucket
CREATE POLICY "Avatar images are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own avatar"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Storage policies for blueprints bucket
CREATE POLICY "Authenticated users can view blueprints"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'blueprints' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can upload blueprints"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'blueprints' AND auth.role() = 'authenticated');

-- Storage policies for receipts bucket  
CREATE POLICY "Authenticated users can view receipts"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'receipts' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can upload receipts"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'receipts' AND auth.role() = 'authenticated');

-- ============================================================
-- 17. SEED DATA FOR TESTING
-- ============================================================

-- NOTE: Run this separately after creating a super_admin user via Supabase Auth
-- Replace 'YOUR_SUPER_ADMIN_USER_ID' with actual UUID

-- UPDATE public.user_profiles 
-- SET role = 'super_admin', full_name = 'Super Admin'
-- WHERE id = 'YOUR_SUPER_ADMIN_USER_ID';

-- ============================================================
-- END OF MIGRATION
-- ============================================================


-- ============================================================
-- 002_fix_rls_policies.sql
-- ============================================================
-- ============================================================
-- FIX: RLS INFINITE RECURSION ON USER_PROFILES
-- ============================================================
-- Run this AFTER 001_initial_schema.sql
-- This fixes the infinite recursion issue in RLS policies
-- ============================================================

-- Step 1: Drop the problematic policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Super admins can update any profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Super admins can insert profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Super admins can delete profiles" ON public.user_profiles;

-- Step 2: Create a SECURITY DEFINER function to get user role
-- This function bypasses RLS to check the user's role
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM public.user_profiles WHERE id = auth.uid();
$$;

-- Step 3: Create a function to check if user is admin or super_admin
CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$;

-- Step 4: Create a function to check if user is super_admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  );
$$;

-- ============================================================
-- NEW RLS POLICIES FOR USER_PROFILES (No recursion)
-- ============================================================

-- Policy: Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

-- Policy: Admins can view all profiles (uses function to avoid recursion)
CREATE POLICY "Admins can view all profiles"
    ON public.user_profiles FOR SELECT
    USING (public.is_admin_or_super());

-- Policy: Users can insert their own profile (during signup)
CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Policy: Super admins can update any profile
CREATE POLICY "Super admins can update any profile"
    ON public.user_profiles FOR UPDATE
    USING (public.is_super_admin());

-- Policy: Super admins can delete profiles
CREATE POLICY "Super admins can delete profiles"
    ON public.user_profiles FOR DELETE
    USING (public.is_super_admin());

-- ============================================================
-- FIX: Update other tables to use the helper functions
-- ============================================================

-- Drop and recreate project policies
DROP POLICY IF EXISTS "Admins can view all projects" ON public.projects;
DROP POLICY IF EXISTS "Admins can create projects" ON public.projects;
DROP POLICY IF EXISTS "Admins can update projects" ON public.projects;
DROP POLICY IF EXISTS "Super admins can delete projects" ON public.projects;

CREATE POLICY "Admins can view all projects"
    ON public.projects FOR SELECT
    USING (public.is_admin_or_super());

CREATE POLICY "Admins can create projects"
    ON public.projects FOR INSERT
    WITH CHECK (public.is_admin_or_super());

CREATE POLICY "Admins can update projects"
    ON public.projects FOR UPDATE
    USING (public.is_admin_or_super());

CREATE POLICY "Super admins can delete projects"
    ON public.projects FOR DELETE
    USING (public.is_super_admin());

-- Drop and recreate project_assignments policies
DROP POLICY IF EXISTS "Admins can view all assignments" ON public.project_assignments;
DROP POLICY IF EXISTS "Admins can manage assignments" ON public.project_assignments;

CREATE POLICY "Admins can view all assignments"
    ON public.project_assignments FOR SELECT
    USING (public.is_admin_or_super());

CREATE POLICY "Admins can manage assignments"
    ON public.project_assignments FOR ALL
    USING (public.is_admin_or_super());

-- Drop and recreate stock policies
DROP POLICY IF EXISTS "Admins can manage stock" ON public.stock_items;

CREATE POLICY "Admins can manage stock"
    ON public.stock_items FOR ALL
    USING (public.is_admin_or_super());

-- Drop and recreate labour policies
DROP POLICY IF EXISTS "Admins can manage labour" ON public.labour;

CREATE POLICY "Admins can manage labour"
    ON public.labour FOR ALL
    USING (public.is_admin_or_super());

-- Drop and recreate machinery policies
DROP POLICY IF EXISTS "Admins can manage machinery" ON public.machinery;

CREATE POLICY "Admins can manage machinery"
    ON public.machinery FOR ALL
    USING (public.is_admin_or_super());

-- Drop and recreate bills policies
DROP POLICY IF EXISTS "Admins can manage bills" ON public.bills;

CREATE POLICY "Admins can manage bills"
    ON public.bills FOR ALL
    USING (public.is_admin_or_super());

-- Drop and recreate blueprints policies
DROP POLICY IF EXISTS "Admins can manage blueprints" ON public.blueprints;

CREATE POLICY "Admins can manage blueprints"
    ON public.blueprints FOR ALL
    USING (public.is_admin_or_super());

-- ============================================================
-- GRANT EXECUTE ON FUNCTIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;

-- ============================================================
-- DONE!
-- ============================================================
-- Now the RLS policies use SECURITY DEFINER functions
-- which bypass RLS when checking the user's role,
-- preventing infinite recursion.
-- ============================================================


-- ============================================================
-- 003_add_blueprints.sql
-- ============================================================
-- ============================================================
-- 003: BLUEPRINTS MODULE SCHEMA & POLICIES
-- ============================================================

-- 1. Create Storage Bucket for Blueprints
--    - Make it public for simplicity of access via URLs
--    - RLS policies on the `storage.objects` table will secure it
INSERT INTO storage.buckets (id, name, public)
VALUES ('blueprints', 'blueprints', true)
ON CONFLICT (id) DO NOTHING;


-- 2. Alter the existing `blueprints` table to match the new schema
--    The table was created in 001_initial_schema.sql with different columns
--    We need to migrate it to the new folder-based structure

DO $$ 
DECLARE
    v_has_file_url BOOLEAN;
    v_has_uploaded_by BOOLEAN;
BEGIN
    -- Check if old columns exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'blueprints' 
        AND column_name = 'file_url'
    ) INTO v_has_file_url;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'blueprints' 
        AND column_name = 'uploaded_by'
    ) INTO v_has_uploaded_by;

    -- Add folder_name column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'blueprints' 
                   AND column_name = 'folder_name') THEN
        ALTER TABLE public.blueprints ADD COLUMN folder_name TEXT;
        -- Set a default folder name for existing records
        UPDATE public.blueprints SET folder_name = 'General' WHERE folder_name IS NULL;
        ALTER TABLE public.blueprints ALTER COLUMN folder_name SET NOT NULL;
    END IF;

    -- Add file_name column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'blueprints' 
                   AND column_name = 'file_name') THEN
        ALTER TABLE public.blueprints ADD COLUMN file_name TEXT;
        -- Extract filename from file_url if it exists, otherwise set default
        IF v_has_file_url THEN
            UPDATE public.blueprints 
            SET file_name = COALESCE(
                NULLIF(SPLIT_PART(file_url, '/', -1), ''),
                'unknown_file'
            ) 
            WHERE file_name IS NULL;
        ELSE
            UPDATE public.blueprints SET file_name = 'unknown_file' WHERE file_name IS NULL;
        END IF;
        ALTER TABLE public.blueprints ALTER COLUMN file_name SET NOT NULL;
    END IF;

    -- Add file_path column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'blueprints' 
                   AND column_name = 'file_path') THEN
        ALTER TABLE public.blueprints ADD COLUMN file_path TEXT;
        -- Generate file_path from project_id and folder_name/file_name
        UPDATE public.blueprints 
        SET file_path = project_id::text || '/' || COALESCE(folder_name, 'General') || '/' || file_name
        WHERE file_path IS NULL;
        ALTER TABLE public.blueprints ALTER COLUMN file_path SET NOT NULL;
        -- Add unique constraint if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'blueprints_file_path_unique') THEN
            CREATE UNIQUE INDEX blueprints_file_path_unique ON public.blueprints(file_path);
        END IF;
    END IF;

    -- Add is_admin_only column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'blueprints' 
                   AND column_name = 'is_admin_only') THEN
        ALTER TABLE public.blueprints ADD COLUMN is_admin_only BOOLEAN NOT NULL DEFAULT false;
    END IF;

    -- Handle uploader_id column
    IF v_has_uploaded_by THEN
        -- Rename uploaded_by to uploader_id if uploader_id doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_schema = 'public' 
                       AND table_name = 'blueprints' 
                       AND column_name = 'uploader_id') THEN
            ALTER TABLE public.blueprints RENAME COLUMN uploaded_by TO uploader_id;
        ELSE
            -- Both exist, migrate data and drop old column
            UPDATE public.blueprints SET uploader_id = uploaded_by WHERE uploader_id IS NULL;
            ALTER TABLE public.blueprints DROP COLUMN uploaded_by;
        END IF;
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                      WHERE table_schema = 'public' 
                      AND table_name = 'blueprints' 
                      AND column_name = 'uploader_id') THEN
        ALTER TABLE public.blueprints ADD COLUMN uploader_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;

    -- Ensure created_at exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'blueprints' 
                   AND column_name = 'created_at') THEN
        ALTER TABLE public.blueprints ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();
    END IF;

    -- Drop old columns that are no longer needed (after data migration)
    ALTER TABLE public.blueprints 
        DROP COLUMN IF EXISTS title,
        DROP COLUMN IF EXISTS description,
        DROP COLUMN IF EXISTS file_url,
        DROP COLUMN IF EXISTS file_type,
        DROP COLUMN IF EXISTS file_size,
        DROP COLUMN IF EXISTS version,
        DROP COLUMN IF EXISTS updated_at;
END $$;

-- Update foreign key constraint for project_id if needed
DO $$
BEGIN
    -- Drop existing constraint if it doesn't have CASCADE
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.referential_constraints rc 
        ON tc.constraint_name = rc.constraint_name
        WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'blueprints'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND tc.constraint_name LIKE '%project_id%'
    ) THEN
        -- Check if we need to recreate with CASCADE (simplified - just ensure it exists)
        NULL; -- Constraint exists, leave it
    ELSE
        -- Add foreign key if it doesn't exist
        ALTER TABLE public.blueprints 
        ADD CONSTRAINT blueprints_project_id_fkey 
        FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Add comments to the table and columns
COMMENT ON TABLE public.blueprints IS 'Stores metadata for blueprint files, linking them to projects and folders.';
COMMENT ON COLUMN public.blueprints.folder_name IS 'Logical grouping for files, like a folder.';
COMMENT ON COLUMN public.blueprints.file_path IS 'The full path to the file in the Supabase Storage bucket.';
COMMENT ON COLUMN public.blueprints.is_admin_only IS 'If true, only admins can view this file.';


-- 3. Enable RLS on the new table
ALTER TABLE public.blueprints ENABLE ROW LEVEL SECURITY;

-- 4. Drop existing policy if it exists from previous script
DROP POLICY IF EXISTS "Admins can manage blueprints" ON public.blueprints;


-- 5. RLS Policies for `blueprints` table

-- Policy: Admins can perform all operations
CREATE POLICY "Admins can manage blueprints"
    ON public.blueprints FOR ALL
    USING (public.is_admin_or_super())
    WITH CHECK (public.is_admin_or_super());

-- Policy: Site managers can view non-admin files in their assigned projects
CREATE POLICY "Site managers can view assigned project blueprints"
    ON public.blueprints FOR SELECT
    USING (
      (get_my_role() = 'site_manager') AND
      (is_admin_only = false) AND
      (project_id IN (
        SELECT project_id FROM public.project_assignments WHERE user_id = auth.uid()
      ))
    );
    
-- RLS will implicitly deny access to users who are not admin or site managers.


-- 6. Storage Policies for `blueprints` bucket

-- Function to check if a user is assigned to the project associated with a file path
CREATE OR REPLACE FUNCTION public.is_assigned_to_project_from_path(p_path_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_project_id UUID;
  v_user_role TEXT;
BEGIN
  -- Extract project_id from path (e.g., 'project-uuid/folder/file.pdf')
  BEGIN
    v_project_id := SPLIT_PART(p_path_name, '/', 1)::UUID;
  EXCEPTION WHEN others THEN
    -- If casting fails, it's not a valid path for our case
    RETURN FALSE;
  END;
  
  -- Get user's role
  v_user_role := get_my_role();

  IF v_user_role IN ('admin', 'super_admin') THEN
    RETURN TRUE;
  END IF;

  IF v_user_role = 'site_manager' THEN
    -- Check if manager is assigned to this project
    RETURN EXISTS (
      SELECT 1 FROM public.project_assignments
      WHERE project_assignments.project_id = v_project_id AND project_assignments.user_id = auth.uid()
    );
  END IF;

  RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_assigned_to_project_from_path(TEXT) TO authenticated;

-- Drop existing policies just in case to avoid conflicts
DROP POLICY IF EXISTS "Admins can upload to blueprints" ON storage.objects;
DROP POLICY IF EXISTS "Project members can view blueprint files" ON storage.objects;
DROP POLICY IF EXISTS "Admins can delete blueprint files" ON storage.objects;


-- Policy: Admins can upload files
CREATE POLICY "Admins can upload to blueprints"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'blueprints' AND
        public.is_admin_or_super()
    );

-- Policy: Assigned site managers and admins can view files
CREATE POLICY "Project members can view blueprint files"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'blueprints' AND
        public.is_assigned_to_project_from_path(name)
    );

-- Policy: Admins can update/delete files
CREATE POLICY "Admins can delete blueprint files"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'blueprints' AND
        public.is_admin_or_super()
    );



-- ============================================================
-- 004_fix_table_name.sql
-- ============================================================
-- ============================================================
-- FIX: Table name mismatch and RLS recursion
-- ============================================================
-- This migration fixes two issues:
-- 1. Table named 'profiles' should be 'user_profiles'
-- 2. Infinite recursion in RLS policies
-- ============================================================

-- Step 1: Check if 'profiles' table exists and 'user_profiles' doesn't
-- If so, rename it. If 'user_profiles' already exists, just fix RLS.

-- First, let's handle the case where 'profiles' exists but 'user_profiles' doesn't
DO $$
BEGIN
    -- Check if profiles exists and user_profiles doesn't
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profiles')
    THEN
        -- Rename profiles to user_profiles
        ALTER TABLE public.profiles RENAME TO user_profiles;
        RAISE NOTICE 'Renamed profiles to user_profiles';
    END IF;
END $$;

-- Step 2: If user_profiles still doesn't exist, create it
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'site_manager' CHECK (role IN ('super_admin', 'admin', 'site_manager')),
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Step 3: Drop ALL existing policies on user_profiles to start fresh
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'user_profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.user_profiles', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- Step 4: Create SECURITY DEFINER functions to avoid recursion
-- These functions bypass RLS when checking user role

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.user_profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  );
$$;

-- Step 5: Create NEW RLS POLICIES (no recursion!)

-- SELECT policies
CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
    ON public.user_profiles FOR SELECT
    USING (public.is_admin_or_super());

-- INSERT policy
CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- UPDATE policies
CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Super admins can update any profile"
    ON public.user_profiles FOR UPDATE
    USING (public.is_super_admin());

-- DELETE policy
CREATE POLICY "Super admins can delete profiles"
    ON public.user_profiles FOR DELETE
    USING (public.is_super_admin());

-- Step 6: Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;

-- Step 7: Create/update the trigger function for auto-creating user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, role, full_name, created_at)
    VALUES (
        NEW.id,
        'site_manager',
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create/replace the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Step 8: Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- Step 9: Fix RLS on other tables that reference user_profiles
-- ============================================================

-- Fix projects table policies
DROP POLICY IF EXISTS "Admins can view all projects" ON public.projects;
DROP POLICY IF EXISTS "Admins can create projects" ON public.projects;
DROP POLICY IF EXISTS "Admins can update projects" ON public.projects;
DROP POLICY IF EXISTS "Super admins can delete projects" ON public.projects;

CREATE POLICY "Admins can view all projects"
    ON public.projects FOR SELECT
    USING (public.is_admin_or_super());

CREATE POLICY "Admins can create projects"
    ON public.projects FOR INSERT
    WITH CHECK (public.is_admin_or_super());

CREATE POLICY "Admins can update projects"
    ON public.projects FOR UPDATE
    USING (public.is_admin_or_super());

CREATE POLICY "Super admins can delete projects"
    ON public.projects FOR DELETE
    USING (public.is_super_admin());

-- Fix project_assignments table policies
DROP POLICY IF EXISTS "Admins can view all assignments" ON public.project_assignments;
DROP POLICY IF EXISTS "Admins can manage assignments" ON public.project_assignments;

CREATE POLICY "Admins can view all assignments"
    ON public.project_assignments FOR SELECT
    USING (public.is_admin_or_super());

CREATE POLICY "Admins can manage assignments"
    ON public.project_assignments FOR ALL
    USING (public.is_admin_or_super());

-- ============================================================
-- DONE!
-- ============================================================
-- Now run this SQL in your Supabase SQL Editor:
-- Dashboard: https://supabase.com/dashboard/project/YOUR_PROJECT/sql
-- ============================================================


-- ============================================================
-- 005_add_missing_columns.sql
-- ============================================================
-- ============================================================
-- FIX: Add missing columns to match Flutter code expectations
-- ============================================================
-- Run this in Supabase SQL Editor after migration 004
-- ============================================================

-- ============================================================
-- 1. Add missing columns to PROJECTS table
-- ============================================================

-- Add budget column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'projects' 
        AND column_name = 'budget'
    ) THEN
        ALTER TABLE public.projects ADD COLUMN budget DECIMAL(15, 2);
        RAISE NOTICE 'Added budget column to projects';
    END IF;
END $$;

-- Add start_date column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'projects' 
        AND column_name = 'start_date'
    ) THEN
        ALTER TABLE public.projects ADD COLUMN start_date DATE;
        RAISE NOTICE 'Added start_date column to projects';
    END IF;
END $$;

-- Add end_date column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'projects' 
        AND column_name = 'end_date'
    ) THEN
        ALTER TABLE public.projects ADD COLUMN end_date DATE;
        RAISE NOTICE 'Added end_date column to projects';
    END IF;
END $$;

-- Add created_by column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'projects' 
        AND column_name = 'created_by'
    ) THEN
        ALTER TABLE public.projects ADD COLUMN created_by UUID REFERENCES public.user_profiles(id);
        RAISE NOTICE 'Added created_by column to projects';
    END IF;
END $$;

-- Add location column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'projects' 
        AND column_name = 'location'
    ) THEN
        ALTER TABLE public.projects ADD COLUMN location TEXT;
        RAISE NOTICE 'Added location column to projects';
    END IF;
END $$;

-- Make sure status column has correct check constraint
DO $$
BEGIN
    -- First drop the existing constraint if any
    ALTER TABLE public.projects DROP CONSTRAINT IF EXISTS projects_status_check;
    
    -- Add the correct constraint
    ALTER TABLE public.projects ADD CONSTRAINT projects_status_check 
        CHECK (status IN ('planning', 'in_progress', 'on_hold', 'completed', 'cancelled'));
        
    RAISE NOTICE 'Updated status constraint on projects';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not update status constraint: %', SQLERRM;
END $$;

-- ============================================================
-- 2. Add missing columns to PROJECT_ASSIGNMENTS table
-- ============================================================

-- Add assigned_role column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'project_assignments' 
        AND column_name = 'assigned_role'
    ) THEN
        ALTER TABLE public.project_assignments 
            ADD COLUMN assigned_role TEXT DEFAULT 'manager' 
            CHECK (assigned_role IN ('manager', 'member', 'viewer'));
        RAISE NOTICE 'Added assigned_role column to project_assignments';
    END IF;
END $$;

-- Add assigned_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'project_assignments' 
        AND column_name = 'assigned_at'
    ) THEN
        ALTER TABLE public.project_assignments 
            ADD COLUMN assigned_at TIMESTAMPTZ DEFAULT NOW();
        RAISE NOTICE 'Added assigned_at column to project_assignments';
    END IF;
END $$;

-- Add assigned_by column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'project_assignments' 
        AND column_name = 'assigned_by'
    ) THEN
        ALTER TABLE public.project_assignments 
            ADD COLUMN assigned_by UUID REFERENCES public.user_profiles(id);
        RAISE NOTICE 'Added assigned_by column to project_assignments';
    END IF;
END $$;

-- ============================================================
-- 3. Add missing columns to USER_PROFILES table (if needed)
-- ============================================================

-- Add full_name column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'full_name'
    ) THEN
        ALTER TABLE public.user_profiles ADD COLUMN full_name TEXT;
        RAISE NOTICE 'Added full_name column to user_profiles';
    END IF;
END $$;

-- Add phone column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'phone'
    ) THEN
        ALTER TABLE public.user_profiles ADD COLUMN phone TEXT;
        RAISE NOTICE 'Added phone column to user_profiles';
    END IF;
END $$;

-- Add avatar_url column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'avatar_url'
    ) THEN
        ALTER TABLE public.user_profiles ADD COLUMN avatar_url TEXT;
        RAISE NOTICE 'Added avatar_url column to user_profiles';
    END IF;
END $$;

-- Add role column if it doesn't exist (with correct default and check)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'role'
    ) THEN
        ALTER TABLE public.user_profiles 
            ADD COLUMN role TEXT NOT NULL DEFAULT 'site_manager' 
            CHECK (role IN ('super_admin', 'admin', 'site_manager'));
        RAISE NOTICE 'Added role column to user_profiles';
    END IF;
END $$;

-- ============================================================
-- 4. Create PROJECT_ASSIGNMENTS table if it doesn't exist
-- ============================================================

CREATE TABLE IF NOT EXISTS public.project_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    assigned_role TEXT DEFAULT 'manager' CHECK (assigned_role IN ('manager', 'member', 'viewer')),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES public.user_profiles(id),
    UNIQUE(project_id, user_id)
);

-- Enable RLS on project_assignments
ALTER TABLE public.project_assignments ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 5. Create/Update RLS policies for PROJECT_ASSIGNMENTS
-- ============================================================

-- Drop existing policies first
DROP POLICY IF EXISTS "Users can view own assignments" ON public.project_assignments;
DROP POLICY IF EXISTS "Admins can view all assignments" ON public.project_assignments;
DROP POLICY IF EXISTS "Admins can manage assignments" ON public.project_assignments;

-- Create new policies
CREATE POLICY "Users can view own assignments"
    ON public.project_assignments FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Admins can view all assignments"
    ON public.project_assignments FOR SELECT
    USING (public.is_admin_or_super());

CREATE POLICY "Admins can manage assignments"
    ON public.project_assignments FOR ALL
    USING (public.is_admin_or_super());

-- ============================================================
-- 6. Update RLS policies for PROJECTS to allow Site Manager view
-- ============================================================

-- Drop and recreate site manager view policy
DROP POLICY IF EXISTS "Site managers can view assigned projects" ON public.projects;

CREATE POLICY "Site managers can view assigned projects"
    ON public.projects FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = projects.id AND user_id = auth.uid()
        )
    );

-- ============================================================
-- 7. Verify column existence (optional - for debugging)
-- ============================================================

-- This will show all columns in the key tables
-- SELECT table_name, column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_schema = 'public' 
-- AND table_name IN ('projects', 'project_assignments', 'user_profiles')
-- ORDER BY table_name, ordinal_position;

-- ============================================================
-- DONE!
-- ============================================================
-- After running this migration:
-- 1. projects table will have: budget, start_date, end_date, location, created_by
-- 2. project_assignments table will have: assigned_role, assigned_at, assigned_by
-- 3. user_profiles table will have: full_name, phone, avatar_url, role
-- ============================================================


-- ============================================================
-- 006_fix_signup_trigger.sql
-- ============================================================
-- ============================================================
-- FIX: Signup trigger "Database error saving new user"
-- ============================================================
-- This comprehensive fix ensures user signup works correctly
-- Run this in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- STEP 1: Ensure user_profiles table exists with correct structure
-- ============================================================

-- Create the table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY,
    role TEXT NOT NULL DEFAULT 'site_manager',
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add role constraint if not exists (safe to run multiple times)
DO $$
BEGIN
    ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
    ALTER TABLE public.user_profiles ADD CONSTRAINT user_profiles_role_check 
        CHECK (role IN ('super_admin', 'admin', 'site_manager'));
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not update role constraint: %', SQLERRM;
END $$;

-- Add foreign key to auth.users if not exists
DO $$
BEGIN
    -- Check if constraint exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'user_profiles_id_fkey' 
        AND table_name = 'user_profiles'
    ) THEN
        ALTER TABLE public.user_profiles 
            ADD CONSTRAINT user_profiles_id_fkey 
            FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
        RAISE NOTICE 'Added foreign key constraint';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Foreign key may already exist or auth.users not accessible: %', SQLERRM;
END $$;

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- STEP 2: Drop and recreate ALL policies on user_profiles
-- ============================================================

-- Drop all existing policies
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'user_profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.user_profiles', pol.policyname);
    END LOOP;
END $$;

-- ============================================================
-- STEP 3: Create helper functions (SECURITY DEFINER to avoid RLS recursion)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.user_profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  );
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO anon;
GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO anon;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO anon;

-- ============================================================
-- STEP 4: Create NEW RLS policies
-- ============================================================

-- SELECT: Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

-- SELECT: Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
    ON public.user_profiles FOR SELECT
    USING (public.is_admin_or_super());

-- INSERT: Users can insert their own profile (during signup)
CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- UPDATE: Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- UPDATE: Super admins can update any profile
CREATE POLICY "Super admins can update any profile"
    ON public.user_profiles FOR UPDATE
    USING (public.is_super_admin());

-- DELETE: Super admins can delete profiles
CREATE POLICY "Super admins can delete profiles"
    ON public.user_profiles FOR DELETE
    USING (public.is_super_admin());

-- ============================================================
-- STEP 5: Create the signup trigger function (CRITICAL!)
-- ============================================================

-- This function runs when a new user signs up
-- It creates a profile automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, role, full_name, created_at, updated_at)
    VALUES (
        NEW.id,
        'site_manager',
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = COALESCE(EXCLUDED.full_name, user_profiles.full_name),
        updated_at = NOW();
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log the error but don't fail the signup
    RAISE WARNING 'Could not create user profile: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================================
-- STEP 6: Drop and recreate the trigger
-- ============================================================

-- Drop existing trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create new trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- STEP 7: Grant necessary permissions
-- ============================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Grant permissions on user_profiles table
GRANT SELECT ON public.user_profiles TO anon;
GRANT SELECT, INSERT, UPDATE ON public.user_profiles TO authenticated;

-- ============================================================
-- STEP 8: Create updated_at trigger
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- STEP 9: Verify setup (optional - uncomment to debug)
-- ============================================================

-- Check if trigger exists
-- SELECT tgname, tgrelid::regclass, tgenabled 
-- FROM pg_trigger 
-- WHERE tgname = 'on_auth_user_created';

-- Check user_profiles table structure
-- SELECT column_name, data_type, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'user_profiles' AND table_schema = 'public';

-- Check policies
-- SELECT policyname, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'user_profiles';

-- ============================================================
-- DONE!
-- ============================================================
-- The signup should now work. When a user signs up:
-- 1. Supabase creates the auth.users record
-- 2. The trigger fires and creates a user_profiles record
-- 3. User is redirected to the app with role 'site_manager'
-- ============================================================


-- ============================================================
-- 007_indexes_soft_deletes_realtime.sql
-- ============================================================
-- ============================================================
-- MIGRATION 007: DATABASE INDEXES & SOFT DELETES
-- Performance improvements and data recovery support
-- ============================================================

-- ============================================================
-- PART 1: PERFORMANCE INDEXES
-- ============================================================

-- Projects table indexes
CREATE INDEX IF NOT EXISTS idx_projects_status 
ON projects(status);

CREATE INDEX IF NOT EXISTS idx_projects_created_at 
ON projects(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_projects_created_by 
ON projects(created_by);

-- Project assignments indexes (critical for JOIN performance)
CREATE INDEX IF NOT EXISTS idx_project_assignments_user_id 
ON project_assignments(user_id);

CREATE INDEX IF NOT EXISTS idx_project_assignments_project_id 
ON project_assignments(project_id);

-- Composite index for common query pattern
CREATE INDEX IF NOT EXISTS idx_project_assignments_composite 
ON project_assignments(user_id, project_id);

-- Blueprints indexes
CREATE INDEX IF NOT EXISTS idx_blueprints_project_id 
ON blueprints(project_id);

CREATE INDEX IF NOT EXISTS idx_blueprints_folder 
ON blueprints(project_id, folder_name);

-- User profiles indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_role 
ON user_profiles(role);

-- ============================================================
-- PART 2: SOFT DELETES
-- ============================================================

-- Add deleted_at columns
ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE blueprints 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Create partial indexes for efficient queries on non-deleted records
CREATE INDEX IF NOT EXISTS idx_projects_not_deleted 
ON projects(id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_blueprints_not_deleted 
ON blueprints(id) WHERE deleted_at IS NULL;

-- ============================================================
-- PART 3: SOFT DELETE FUNCTIONS
-- ============================================================

-- Soft delete a project
CREATE OR REPLACE FUNCTION soft_delete_project(p_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE projects 
  SET deleted_at = NOW(), 
      updated_at = NOW()
  WHERE id = p_id AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Restore a soft-deleted project
CREATE OR REPLACE FUNCTION restore_project(p_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE projects 
  SET deleted_at = NULL, 
      updated_at = NOW()
  WHERE id = p_id AND deleted_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Soft delete a blueprint
CREATE OR REPLACE FUNCTION soft_delete_blueprint(b_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE blueprints 
  SET deleted_at = NOW()
  WHERE id = b_id AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PART 4: ENABLE REALTIME
-- ============================================================

-- Enable realtime for projects table
ALTER PUBLICATION supabase_realtime ADD TABLE projects;

-- Enable realtime for project_assignments table  
ALTER PUBLICATION supabase_realtime ADD TABLE project_assignments;

-- ============================================================
-- PART 5: UPDATED_AT TRIGGER (if not exists)
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to projects if not exists
DROP TRIGGER IF EXISTS update_projects_updated_at ON projects;
CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- MIGRATION COMPLETE
-- Run: supabase db push
-- ============================================================


-- ============================================================
-- 008_production_indexes.sql
-- ============================================================
-- ============================================================
-- MIGRATION 008: PRODUCTION PERFORMANCE INDEXES
-- Cursor pagination and RLS optimization
-- ============================================================

-- ============================================================
-- PART 1: CURSOR PAGINATION INDEXES
-- ============================================================

-- Projects: cursor pagination index (for infinite scroll)
CREATE INDEX IF NOT EXISTS idx_projects_cursor 
ON projects(created_at DESC, id DESC) 
WHERE deleted_at IS NULL;

-- Blueprints: cursor pagination within project
CREATE INDEX IF NOT EXISTS idx_blueprints_cursor
ON blueprints(project_id, created_at DESC, id DESC)
WHERE deleted_at IS NULL;

-- ============================================================
-- PART 2: RLS PERFORMANCE INDEXES
-- ============================================================

-- Project assignments: composite for RLS checks
CREATE INDEX IF NOT EXISTS idx_assignments_user_project_role
ON project_assignments(user_id, project_id, assigned_role);

-- User profiles: role lookup with created_at for listing
CREATE INDEX IF NOT EXISTS idx_user_profiles_role_created
ON user_profiles(role, created_at DESC);

-- ============================================================
-- PART 3: QUERY OPTIMIZATION INDEXES
-- ============================================================

-- Projects: status + created for filtered lists
CREATE INDEX IF NOT EXISTS idx_projects_status_created
ON projects(status, created_at DESC)
WHERE deleted_at IS NULL;

-- Blueprints: folder listing within project
CREATE INDEX IF NOT EXISTS idx_blueprints_project_folder_created
ON blueprints(project_id, folder_name, created_at DESC)
WHERE deleted_at IS NULL;

-- ============================================================
-- MIGRATION COMPLETE
-- Run: supabase db push
-- ============================================================


-- ============================================================
-- 009_fix_admin_user_management.sql
-- ============================================================
-- ============================================================
-- MIGRATION 009: FIX RLS FOR ADMIN USER MANAGEMENT
-- Allows admins to create and manage site manager profiles
-- ============================================================

-- ============================================================
-- PART 1: FIX USER_PROFILES RLS FOR ADMIN
-- ============================================================

-- Drop the restrictive insert policy
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;

-- Allow users to insert their own profile (signup) OR admins to insert any profile
CREATE POLICY "Users or admins can insert profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (
        auth.uid() = id  -- User creating their own profile
        OR public.is_admin_or_super()  -- Admin creating profile for another user
    );

-- Also allow admins to update any profile (not just super_admin)
DROP POLICY IF EXISTS "Super admins can update any profile" ON public.user_profiles;

CREATE POLICY "Admins can update any profile"
    ON public.user_profiles FOR UPDATE
    USING (
        auth.uid() = id  -- User updating own profile
        OR public.is_admin_or_super()  -- Admin updating any profile
    );

-- ============================================================
-- PART 2: ADD UPLOADER_ID COLUMN TO BLUEPRINTS
-- ============================================================

-- Add uploader_id column if it doesn't exist
ALTER TABLE public.blueprints 
ADD COLUMN IF NOT EXISTS uploader_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_blueprints_uploader_id
ON blueprints(uploader_id);

-- ============================================================
-- MIGRATION COMPLETE
-- Run: supabase db push
-- ============================================================


-- ============================================================
-- 010_storage_policies.sql
-- ============================================================
-- ============================================================
-- MIGRATION 010: STORAGE POLICIES FOR PRIVATE BUCKETS
-- Secure storage access with project-based authorization
-- ============================================================

-- ============================================================
-- PART 1: HELPER FUNCTION TO CHECK PROJECT ASSIGNMENT
-- ============================================================

-- Check if current user is assigned to a project
CREATE OR REPLACE FUNCTION public.is_assigned_to_project(p_project_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.project_assignments pa
    WHERE pa.user_id = auth.uid()
      AND pa.project_id = p_project_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_assigned_to_project(uuid) TO authenticated;

-- ============================================================
-- PART 2: FIX uploaded_by DEFAULT (prevents null constraint errors)
-- ============================================================

ALTER TABLE public.blueprints
ALTER COLUMN uploaded_by SET DEFAULT auth.uid();

-- ============================================================
-- PART 3: STORAGE POLICIES FOR BLUEPRINTS BUCKET
-- Path format: <projectId>/<folderName>/<fileName>
-- ============================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "blueprints_read_assigned" ON storage.objects;
DROP POLICY IF EXISTS "blueprints_upload_assigned" ON storage.objects;
DROP POLICY IF EXISTS "blueprints_delete_admin" ON storage.objects;
DROP POLICY IF EXISTS "blueprints_update_admin" ON storage.objects;

-- SELECT (view/download/list) - Assigned users + Admins
CREATE POLICY "blueprints_read_assigned"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'blueprints'
  AND (
    public.is_admin_or_super()
    OR public.is_assigned_to_project(
      (split_part(name, '/', 1))::uuid
    )
  )
);

-- INSERT (upload) - Assigned users + Admins
CREATE POLICY "blueprints_upload_assigned"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'blueprints'
  AND (
    public.is_admin_or_super()
    OR public.is_assigned_to_project(
      (split_part(name, '/', 1))::uuid
    )
  )
);

-- DELETE (remove) - Admin only
CREATE POLICY "blueprints_delete_admin"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'blueprints'
  AND public.is_admin_or_super()
);

-- UPDATE (overwrite) - Admin only
CREATE POLICY "blueprints_update_admin"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'blueprints'
  AND public.is_admin_or_super()
);

-- ============================================================
-- PART 4: STORAGE POLICIES FOR BILLS BUCKET
-- Path format: <projectId>/<billId>/<fileName>
-- ============================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "bills_read_admin_or_assigned" ON storage.objects;
DROP POLICY IF EXISTS "bills_upload_assigned" ON storage.objects;
DROP POLICY IF EXISTS "bills_delete_admin" ON storage.objects;
DROP POLICY IF EXISTS "bills_update_admin" ON storage.objects;

-- SELECT (view/download) - Admin + assigned site manager
CREATE POLICY "bills_read_admin_or_assigned"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'bills'
  AND (
    public.is_admin_or_super()
    OR public.is_assigned_to_project(
      (split_part(name, '/', 1))::uuid
    )
  )
);

-- INSERT (upload) - Assigned users + Admins
CREATE POLICY "bills_upload_assigned"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'bills'
  AND (
    public.is_admin_or_super()
    OR public.is_assigned_to_project(
      (split_part(name, '/', 1))::uuid
    )
  )
);

-- DELETE - Admin only
CREATE POLICY "bills_delete_admin"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'bills'
  AND public.is_admin_or_super()
);

-- UPDATE - Admin only
CREATE POLICY "bills_update_admin"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'bills'
  AND public.is_admin_or_super()
);

-- ============================================================
-- MIGRATION COMPLETE
-- Run: supabase db push
-- ============================================================


-- ============================================================
-- 011_material_logs.sql
-- ============================================================
-- ============================================================
-- MIGRATION 011: STOCK ITEMS + MATERIAL LOGS
-- Creates stock_items if missing and material_logs for tracking
-- ============================================================

-- ============================================================
-- PART 1: STOCK ITEMS TABLE (if not exists)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.stock_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    unit TEXT DEFAULT 'units',
    quantity DECIMAL(15, 2) DEFAULT 0,
    min_quantity DECIMAL(15, 2) DEFAULT 0,
    low_stock_threshold DECIMAL DEFAULT 10,
    unit_price DECIMAL(15, 2),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on stock_items
ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;

-- Stock items RLS policies
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins can manage stock' AND tablename = 'stock_items') THEN
    CREATE POLICY "Admins can manage stock"
      ON public.stock_items FOR ALL
      USING (public.is_admin_or_super());
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Site managers can view project stock' AND tablename = 'stock_items') THEN
    CREATE POLICY "Site managers can view project stock"
      ON public.stock_items FOR SELECT
      USING (public.is_assigned_to_project(project_id));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Site managers can update project stock' AND tablename = 'stock_items') THEN
    CREATE POLICY "Site managers can update project stock"
      ON public.stock_items FOR UPDATE
      USING (public.is_assigned_to_project(project_id));
  END IF;
END $$;

-- ============================================================
-- PART 2: MATERIAL LOGS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.material_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.stock_items(id) ON DELETE CASCADE,
  log_type TEXT NOT NULL CHECK (log_type IN ('inward', 'outward')),
  quantity DECIMAL NOT NULL CHECK (quantity > 0),
  activity TEXT,
  challan_url TEXT,
  logged_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  logged_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PART 3: INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_material_logs_project
ON material_logs(project_id, logged_at DESC);

CREATE INDEX IF NOT EXISTS idx_material_logs_item
ON material_logs(item_id, logged_at DESC);

CREATE INDEX IF NOT EXISTS idx_material_logs_type
ON material_logs(project_id, log_type, logged_at DESC);

CREATE INDEX IF NOT EXISTS idx_stock_items_project
ON stock_items(project_id);

-- ============================================================
-- PART 4: RLS POLICIES FOR MATERIAL LOGS
-- ============================================================

ALTER TABLE public.material_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage material logs"
ON public.material_logs FOR ALL
USING (public.is_admin_or_super());

CREATE POLICY "Site managers can view assigned project logs"
ON public.material_logs FOR SELECT
USING (public.is_assigned_to_project(project_id));

CREATE POLICY "Site managers can insert logs for assigned projects"
ON public.material_logs FOR INSERT
WITH CHECK (public.is_assigned_to_project(project_id));

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================


-- ============================================================
-- 012_seed_admin_users.sql
-- ============================================================
-- ============================================================
-- SEED ADMIN USERS FOR CLIVI MANAGEMENT
-- ============================================================
-- This script creates Super Admin and Admin users
-- 
-- IMPORTANT: Run these steps in order:
-- 1. First, create the users in Supabase Auth Dashboard OR via API
-- 2. Then run the user_profiles INSERT below
-- ============================================================

-- ============================================================
-- OPTION 1: Create Users via Supabase Dashboard
-- ============================================================
-- Go to: https://supabase.com/dashboard/project/YOUR_PROJECT/auth/users
-- Click "Add user" -> "Create new user"
-- 
-- USER 1 (Super Admin):
--   Email: admin@gmail.com
--   Password: Admin12345
--   Email Confirm: ON (toggle to confirm automatically)
--
-- USER 2 (Admin):
--   Email: admin@gmail.com  (same email - create a second account with different email)
--   OR create a different admin like: admin2@gmail.com / Admin12345
-- ============================================================

-- ============================================================
-- OPTION 2: Create Users via Supabase SQL (Service Role Required)
-- ============================================================
-- NOTE: This requires running with service_role key privileges
-- These will NOT work in client-side code - only in Supabase SQL Editor
-- with proper permissions or via Supabase Admin API

-- For creating users programmatically, use Supabase Admin API:
/*
-- Using Supabase JavaScript Admin Client:

const { createClient } = require('@supabase/supabase-js');

const supabaseAdmin = createClient(
  'YOUR_SUPABASE_URL',
  'YOUR_SERVICE_ROLE_KEY' // NOT the anon key
);

// Create Super Admin
const { data: superAdmin, error: superAdminError } = await supabaseAdmin.auth.admin.createUser({
  email: 'superadmin@gmail.com',
  password: 'Admin12345',
  email_confirm: true,
  user_metadata: {
    full_name: 'Super Admin'
  }
});

// Create Admin
const { data: admin, error: adminError } = await supabaseAdmin.auth.admin.createUser({
  email: 'admin@gmail.com', 
  password: 'Admin12345',
  email_confirm: true,
  user_metadata: {
    full_name: 'Admin User'
  }
});

console.log('Super Admin ID:', superAdmin.user.id);
console.log('Admin ID:', admin.user.id);
*/

-- ============================================================
-- STEP 2: Update User Profiles (After Users Exist in Auth)
-- ============================================================
-- Replace the UUIDs below with the actual UUIDs from auth.users
-- You can find them in Supabase Dashboard -> Authentication -> Users

-- Get user IDs from auth.users table
-- SELECT id, email FROM auth.users WHERE email IN ('superadmin@gmail.com', 'admin@gmail.com');

-- Update Super Admin role
UPDATE public.user_profiles 
SET 
    role = 'super_admin',
    full_name = 'Super Admin',
    updated_at = NOW()
WHERE id = (SELECT id FROM auth.users WHERE email = 'superadmin@gmail.com' LIMIT 1);

-- Update Admin role
UPDATE public.user_profiles 
SET 
    role = 'admin',
    full_name = 'Admin User',
    updated_at = NOW()
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@gmail.com' LIMIT 1);

-- ============================================================
-- ALTERNATIVE: Direct Insert (if user_profile not auto-created)
-- ============================================================
-- If the trigger didn't create the profile, insert manually:

-- INSERT INTO public.user_profiles (id, role, full_name, created_at)
-- SELECT id, 'super_admin', 'Super Admin', NOW()
-- FROM auth.users WHERE email = 'superadmin@gmail.com'
-- ON CONFLICT (id) DO UPDATE SET role = 'super_admin', full_name = 'Super Admin';

-- INSERT INTO public.user_profiles (id, role, full_name, created_at)
-- SELECT id, 'admin', 'Admin User', NOW()
-- FROM auth.users WHERE email = 'admin@gmail.com'
-- ON CONFLICT (id) DO UPDATE SET role = 'admin', full_name = 'Admin User';

-- ============================================================
-- VERIFICATION QUERY
-- ============================================================
-- Run this to verify the users were created correctly:
-- SELECT up.id, u.email, up.role, up.full_name 
-- FROM public.user_profiles up
-- JOIN auth.users u ON u.id = up.id
-- WHERE up.role IN ('super_admin', 'admin');

-- ============================================================
-- END OF MIGRATION
-- ============================================================


-- ============================================================
-- 013_fix_labour_stock_rls.sql
-- ============================================================
-- ============================================================
-- MIGRATION 013: CREATE TABLES & FIX RLS POLICIES
-- Creates labour, stock, attendance, material_logs tables if missing
-- Then applies proper RLS policies for Admin and Site Managers
-- ============================================================

-- ============================================================
-- PART 0: ENSURE HELPER FUNCTIONS EXIST
-- ============================================================

-- Check if user is admin or super_admin
CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$;

-- Check if user is assigned to a project
CREATE OR REPLACE FUNCTION public.is_assigned_to_project(p_project_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.project_assignments pa
    WHERE pa.user_id = auth.uid()
      AND pa.project_id = p_project_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_assigned_to_project(uuid) TO authenticated;

-- ============================================================
-- PART 1: CREATE LABOUR TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.labour (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    skill_type TEXT,
    daily_wage DECIMAL(10, 2),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.labour ENABLE ROW LEVEL SECURITY;

-- Drop existing policies safely
DROP POLICY IF EXISTS "Admins can manage labour" ON public.labour;
DROP POLICY IF EXISTS "Site managers can manage project labour" ON public.labour;
DROP POLICY IF EXISTS "Site managers can view project labour" ON public.labour;
DROP POLICY IF EXISTS "Site managers can add project labour" ON public.labour;
DROP POLICY IF EXISTS "Site managers can update project labour" ON public.labour;
DROP POLICY IF EXISTS "Site managers can delete project labour" ON public.labour;

-- Admin/Super Admin: Full access
CREATE POLICY "Admins can manage labour"
ON public.labour FOR ALL
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

-- Site Managers: SELECT
CREATE POLICY "Site managers can view project labour"
ON public.labour FOR SELECT
USING (public.is_assigned_to_project(project_id));

-- Site Managers: INSERT
CREATE POLICY "Site managers can add project labour"
ON public.labour FOR INSERT
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: UPDATE
CREATE POLICY "Site managers can update project labour"
ON public.labour FOR UPDATE
USING (public.is_assigned_to_project(project_id))
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: DELETE
CREATE POLICY "Site managers can delete project labour"
ON public.labour FOR DELETE
USING (public.is_assigned_to_project(project_id));

-- ============================================================
-- PART 2: CREATE LABOUR_ATTENDANCE TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.labour_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    labour_id UUID NOT NULL REFERENCES public.labour(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT DEFAULT 'present' CHECK (status IN ('present', 'absent', 'half_day')),
    hours_worked DECIMAL(4, 2),
    notes TEXT,
    recorded_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(labour_id, date)
);

-- Enable RLS
ALTER TABLE public.labour_attendance ENABLE ROW LEVEL SECURITY;

-- Drop existing policies safely
DROP POLICY IF EXISTS "Site managers can manage attendance" ON public.labour_attendance;
DROP POLICY IF EXISTS "Admins can manage attendance" ON public.labour_attendance;
DROP POLICY IF EXISTS "Site managers can view project attendance" ON public.labour_attendance;
DROP POLICY IF EXISTS "Site managers can add project attendance" ON public.labour_attendance;
DROP POLICY IF EXISTS "Site managers can update project attendance" ON public.labour_attendance;
DROP POLICY IF EXISTS "Site managers can delete project attendance" ON public.labour_attendance;

-- Admin/Super Admin: Full access
CREATE POLICY "Admins can manage attendance"
ON public.labour_attendance FOR ALL
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

-- Site Managers: SELECT
CREATE POLICY "Site managers can view project attendance"
ON public.labour_attendance FOR SELECT
USING (public.is_assigned_to_project(project_id));

-- Site Managers: INSERT
CREATE POLICY "Site managers can add project attendance"
ON public.labour_attendance FOR INSERT
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: UPDATE
CREATE POLICY "Site managers can update project attendance"
ON public.labour_attendance FOR UPDATE
USING (public.is_assigned_to_project(project_id))
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: DELETE
CREATE POLICY "Site managers can delete project attendance"
ON public.labour_attendance FOR DELETE
USING (public.is_assigned_to_project(project_id));

-- ============================================================
-- PART 3: CREATE STOCK_ITEMS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.stock_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    unit TEXT DEFAULT 'units',
    quantity DECIMAL(15, 2) DEFAULT 0,
    min_quantity DECIMAL(15, 2) DEFAULT 0,
    low_stock_threshold DECIMAL DEFAULT 10,
    unit_price DECIMAL(15, 2),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies safely
DROP POLICY IF EXISTS "Admins can manage stock" ON public.stock_items;
DROP POLICY IF EXISTS "Site managers can view project stock" ON public.stock_items;
DROP POLICY IF EXISTS "Site managers can update project stock" ON public.stock_items;
DROP POLICY IF EXISTS "Site managers can add project stock" ON public.stock_items;
DROP POLICY IF EXISTS "Site managers can delete project stock" ON public.stock_items;

-- Admin/Super Admin: Full access
CREATE POLICY "Admins can manage stock"
ON public.stock_items FOR ALL
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

-- Site Managers: SELECT
CREATE POLICY "Site managers can view project stock"
ON public.stock_items FOR SELECT
USING (public.is_assigned_to_project(project_id));

-- Site Managers: INSERT
CREATE POLICY "Site managers can add project stock"
ON public.stock_items FOR INSERT
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: UPDATE
CREATE POLICY "Site managers can update project stock"
ON public.stock_items FOR UPDATE
USING (public.is_assigned_to_project(project_id))
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: DELETE
CREATE POLICY "Site managers can delete project stock"
ON public.stock_items FOR DELETE
USING (public.is_assigned_to_project(project_id));

-- ============================================================
-- PART 4: CREATE MATERIAL_LOGS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.material_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.stock_items(id) ON DELETE CASCADE,
  log_type TEXT NOT NULL CHECK (log_type IN ('inward', 'outward')),
  quantity DECIMAL NOT NULL CHECK (quantity > 0),
  activity TEXT,
  challan_url TEXT,
  logged_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  logged_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.material_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies safely
DROP POLICY IF EXISTS "Admins can manage material logs" ON public.material_logs;
DROP POLICY IF EXISTS "Site managers can view assigned project logs" ON public.material_logs;
DROP POLICY IF EXISTS "Site managers can insert logs for assigned projects" ON public.material_logs;
DROP POLICY IF EXISTS "Site managers can view project material logs" ON public.material_logs;
DROP POLICY IF EXISTS "Site managers can add project material logs" ON public.material_logs;
DROP POLICY IF EXISTS "Site managers can update project material logs" ON public.material_logs;
DROP POLICY IF EXISTS "Site managers can delete project material logs" ON public.material_logs;

-- Admin/Super Admin: Full access
CREATE POLICY "Admins can manage material logs"
ON public.material_logs FOR ALL
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

-- Site Managers: SELECT
CREATE POLICY "Site managers can view project material logs"
ON public.material_logs FOR SELECT
USING (public.is_assigned_to_project(project_id));

-- Site Managers: INSERT
CREATE POLICY "Site managers can add project material logs"
ON public.material_logs FOR INSERT
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: UPDATE
CREATE POLICY "Site managers can update project material logs"
ON public.material_logs FOR UPDATE
USING (public.is_assigned_to_project(project_id))
WITH CHECK (public.is_assigned_to_project(project_id));

-- Site Managers: DELETE
CREATE POLICY "Site managers can delete project material logs"
ON public.material_logs FOR DELETE
USING (public.is_assigned_to_project(project_id));

-- ============================================================
-- PART 5: CREATE INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_labour_project ON public.labour(project_id);
CREATE INDEX IF NOT EXISTS idx_labour_status ON public.labour(project_id, status);
CREATE INDEX IF NOT EXISTS idx_attendance_project_date ON public.labour_attendance(project_id, date);
CREATE INDEX IF NOT EXISTS idx_attendance_labour ON public.labour_attendance(labour_id, date);
CREATE INDEX IF NOT EXISTS idx_stock_project ON public.stock_items(project_id);
CREATE INDEX IF NOT EXISTS idx_material_logs_project ON public.material_logs(project_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_material_logs_item ON public.material_logs(item_id, logged_at DESC);

-- ============================================================
-- PART 6: CREATE TRIGGER FOR UPDATED_AT
-- ============================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
DROP TRIGGER IF EXISTS update_labour_updated_at ON public.labour;
CREATE TRIGGER update_labour_updated_at
    BEFORE UPDATE ON public.labour
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_stock_items_updated_at ON public.stock_items;
CREATE TRIGGER update_stock_items_updated_at
    BEFORE UPDATE ON public.stock_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- MIGRATION COMPLETE
-- Run in Supabase SQL Editor
-- ============================================================


-- ============================================================
-- 014_add_user_profile_columns.sql
-- ============================================================
-- ============================================================
-- MIGRATION 014: ADD USER PROFILE COLUMNS
-- Adds email and company_id columns to user_profiles
-- ============================================================

-- ============================================================
-- PART 1: ADD NEW COLUMNS
-- ============================================================

-- Add email column (synced from auth.users)
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS email TEXT;

-- Add company_id column for future multi-tenant support
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS company_id UUID;

-- ============================================================
-- PART 2: CREATE INDEX FOR EMAIL LOOKUPS
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_user_profiles_email
ON public.user_profiles(email);

CREATE INDEX IF NOT EXISTS idx_user_profiles_company
ON public.user_profiles(company_id);

-- ============================================================
-- PART 3: UPDATE HANDLE_NEW_USER FUNCTION TO SYNC EMAIL
-- ============================================================

-- Update the trigger function to include email when creating profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, role, full_name, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        'site_manager',
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PART 4: BACKFILL EMAIL FOR EXISTING USERS
-- ============================================================

-- Sync email from auth.users to user_profiles for existing records
UPDATE public.user_profiles up
SET email = au.email
FROM auth.users au
WHERE up.id = au.id AND up.email IS NULL;

-- ============================================================
-- MIGRATION COMPLETE
-- Run in Supabase SQL Editor
-- ============================================================


-- ============================================================
-- 015_dashboard_schema.sql
-- ============================================================
-- ============================================================
-- MIGRATION 015: DASHBOARD SCHEMA
-- Creates operation_logs table and RPC functions for dashboard
-- ============================================================

-- ============================================================
-- PART 1: OPERATION LOGS TABLE
-- Tracks all significant operations for activity feeds
-- ============================================================

CREATE TABLE IF NOT EXISTS public.operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    operation_type TEXT NOT NULL CHECK (operation_type IN ('create', 'update', 'delete', 'upload', 'status_change')),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('project', 'stock', 'labour', 'blueprint', 'machinery', 'attendance', 'report')),
    entity_id UUID,
    title TEXT NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.operation_logs ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_operation_logs_user ON public.operation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_project ON public.operation_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_created ON public.operation_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_operation_logs_entity ON public.operation_logs(entity_type, entity_id);

-- ============================================================
-- PART 2: RLS POLICIES FOR OPERATION LOGS
-- ============================================================

-- Admins can see all operation logs
CREATE POLICY "Admins can view all operation logs"
ON public.operation_logs FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
);

-- Site managers can see logs for their assigned projects
CREATE POLICY "Site managers can view assigned project logs"
ON public.operation_logs FOR SELECT
TO authenticated
USING (
    project_id IN (
        SELECT project_id FROM public.project_assignments
        WHERE user_id = auth.uid()
    )
);

-- Anyone can insert operation logs (for triggers)
CREATE POLICY "Users can create operation logs"
ON public.operation_logs FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

-- ============================================================
-- PART 3: GET DASHBOARD STATS RPC FUNCTION
-- Returns all dashboard metrics in a single call
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_user_id UUID DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    user_role TEXT;
    accessible_projects UUID[];
BEGIN
    -- Get user role
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = COALESCE(p_user_id, auth.uid());

    -- Get accessible project IDs based on role
    IF user_role IN ('admin', 'super_admin') THEN
        SELECT array_agg(id) INTO accessible_projects FROM public.projects WHERE status != 'cancelled';
    ELSE
        SELECT array_agg(project_id) INTO accessible_projects
        FROM public.project_assignments
        WHERE user_id = COALESCE(p_user_id, auth.uid());
    END IF;

    -- Build stats JSON
    SELECT json_build_object(
        'active_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'in_progress'
        ),
        'total_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
        ),
        'total_workers', (
            SELECT COALESCE(COUNT(*), 0) FROM public.labour 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'active'
        ),
        'low_stock_items', (
            SELECT COUNT(*) FROM public.stock_items 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND quantity <= COALESCE(low_stock_threshold, 10)
        ),
        'pending_reports', (
            SELECT COUNT(*) FROM public.daily_reports 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'pending'
        ),
        'blueprints_count', (
            SELECT COUNT(*) FROM public.blueprints 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
        ),
        'growth_percentage', 12.5, -- Placeholder: calculate weekly growth
        'last_updated', NOW()
    ) INTO result;

    RETURN result;
END;
$$;

-- ============================================================
-- PART 4: GET RECENT ACTIVITY RPC FUNCTION
-- Returns recent operation logs for activity feed
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_recent_activity(
    p_limit INT DEFAULT 10,
    p_offset INT DEFAULT 0,
    p_project_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    user_role TEXT;
BEGIN
    -- Get user role
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = auth.uid();

    -- Return activity based on role
    IF user_role IN ('admin', 'super_admin') THEN
        SELECT json_agg(activity) INTO result
        FROM (
            SELECT json_build_object(
                'id', ol.id,
                'operation_type', ol.operation_type,
                'entity_type', ol.entity_type,
                'title', ol.title,
                'description', ol.description,
                'project_name', p.name,
                'user_name', up.full_name,
                'created_at', ol.created_at
            ) as activity
            FROM public.operation_logs ol
            LEFT JOIN public.projects p ON ol.project_id = p.id
            LEFT JOIN public.user_profiles up ON ol.user_id = up.id
            WHERE (p_project_id IS NULL OR ol.project_id = p_project_id)
            ORDER BY ol.created_at DESC
            LIMIT p_limit OFFSET p_offset
        ) sub;
    ELSE
        -- Site managers see only their assigned projects
        SELECT json_agg(activity) INTO result
        FROM (
            SELECT json_build_object(
                'id', ol.id,
                'operation_type', ol.operation_type,
                'entity_type', ol.entity_type,
                'title', ol.title,
                'description', ol.description,
                'project_name', p.name,
                'user_name', up.full_name,
                'created_at', ol.created_at
            ) as activity
            FROM public.operation_logs ol
            LEFT JOIN public.projects p ON ol.project_id = p.id
            LEFT JOIN public.user_profiles up ON ol.user_id = up.id
            WHERE ol.project_id IN (
                SELECT project_id FROM public.project_assignments
                WHERE user_id = auth.uid()
            )
            AND (p_project_id IS NULL OR ol.project_id = p_project_id)
            ORDER BY ol.created_at DESC
            LIMIT p_limit OFFSET p_offset
        ) sub;
    END IF;

    RETURN COALESCE(result, '[]'::JSON);
END;
$$;

-- ============================================================
-- PART 5: GET ACTIVE PROJECTS SUMMARY RPC
-- Returns top N active projects with progress
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_active_projects_summary(p_limit INT DEFAULT 3)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    user_role TEXT;
BEGIN
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF user_role IN ('admin', 'super_admin') THEN
        SELECT json_agg(proj) INTO result
        FROM (
            SELECT json_build_object(
                'id', p.id,
                'name', p.name,
                'project_type', p.project_type,
                'status', p.status,
                'progress', COALESCE(p.progress, 0),
                'start_date', p.start_date,
                'end_date', p.end_date,
                'location', p.location
            ) as proj
            FROM public.projects p
            WHERE p.status = 'in_progress'
            ORDER BY p.updated_at DESC
            LIMIT p_limit
        ) sub;
    ELSE
        SELECT json_agg(proj) INTO result
        FROM (
            SELECT json_build_object(
                'id', p.id,
                'name', p.name,
                'project_type', p.project_type,
                'status', p.status,
                'progress', COALESCE(p.progress, 0),
                'start_date', p.start_date,
                'end_date', p.end_date,
                'location', p.location
            ) as proj
            FROM public.projects p
            JOIN public.project_assignments pa ON p.id = pa.project_id
            WHERE pa.user_id = auth.uid()
            AND p.status = 'in_progress'
            ORDER BY p.updated_at DESC
            LIMIT p_limit
        ) sub;
    END IF;

    RETURN COALESCE(result, '[]'::JSON);
END;
$$;

-- ============================================================
-- PART 6: LOG OPERATION HELPER FUNCTION
-- Convenience function for logging operations
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_operation(
    p_operation_type TEXT,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_project_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_log_id UUID;
BEGIN
    INSERT INTO public.operation_logs (
        user_id, project_id, operation_type, entity_type, 
        entity_id, title, description, metadata
    ) VALUES (
        auth.uid(), p_project_id, p_operation_type, p_entity_type,
        p_entity_id, p_title, p_description, p_metadata
    )
    RETURNING id INTO new_log_id;
    
    RETURN new_log_id;
END;
$$;

-- ============================================================
-- PART 7: AUTO-LOGGING TRIGGERS
-- Automatically log significant operations
-- ============================================================

-- Trigger function for projects
CREATE OR REPLACE FUNCTION public.log_project_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM public.log_operation(
            'create', 'project', NEW.id,
            'New project created: ' || NEW.name,
            'Project type: ' || COALESCE(NEW.project_type, 'N/A'),
            NEW.id
        );
    ELSIF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
        PERFORM public.log_operation(
            'status_change', 'project', NEW.id,
            'Project status changed: ' || NEW.name,
            'Changed from ' || OLD.status || ' to ' || NEW.status,
            NEW.id
        );
    END IF;
    RETURN NEW;
END;
$$;

-- Create trigger for projects (drop if exists first)
DROP TRIGGER IF EXISTS trigger_log_project_changes ON public.projects;
CREATE TRIGGER trigger_log_project_changes
AFTER INSERT OR UPDATE ON public.projects
FOR EACH ROW EXECUTE FUNCTION public.log_project_changes();

-- Trigger function for blueprints
CREATE OR REPLACE FUNCTION public.log_blueprint_upload()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM public.log_operation(
        'upload', 'blueprint', NEW.id,
        'Blueprint uploaded: ' || NEW.title,
        'Version: ' || COALESCE(NEW.version, '1.0'),
        NEW.project_id
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_log_blueprint_upload ON public.blueprints;
CREATE TRIGGER trigger_log_blueprint_upload
AFTER INSERT ON public.blueprints
FOR EACH ROW EXECUTE FUNCTION public.log_blueprint_upload();

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.get_dashboard_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_recent_activity TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_projects_summary TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_operation TO authenticated;

-- ============================================================
-- MIGRATION COMPLETE
-- Run in Supabase SQL Editor
-- ============================================================


-- ============================================================
-- 016_update_projects.sql
-- ============================================================
-- ============================================================
-- MIGRATION 016: UPDATE PROJECTS TABLE
-- Adds client_name, project_type, progress, deleted_at columns
-- Implements soft delete and project stats RPC
-- ============================================================

-- ============================================================
-- PART 1: ADD NEW COLUMNS TO PROJECTS TABLE
-- ============================================================

-- Add client_name column
ALTER TABLE public.projects 
ADD COLUMN IF NOT EXISTS client_name TEXT;

-- Add project_type column with enum validation
ALTER TABLE public.projects 
ADD COLUMN IF NOT EXISTS project_type TEXT 
CHECK (project_type IN ('Residential', 'Commercial', 'Infrastructure', 'Industrial'));

-- Add progress column (0-100 percentage)
ALTER TABLE public.projects 
ADD COLUMN IF NOT EXISTS progress INT DEFAULT 0 
CHECK (progress >= 0 AND progress <= 100);

-- Add deleted_at for soft delete
ALTER TABLE public.projects 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- ============================================================
-- PART 2: UPDATE RLS POLICIES FOR SOFT DELETE
-- ============================================================

-- Drop existing select policies to recreate with soft delete filter
DROP POLICY IF EXISTS "Admins can view all projects" ON public.projects;
DROP POLICY IF EXISTS "Site managers can view assigned projects" ON public.projects;

-- Recreate admin policy with soft delete filter
CREATE POLICY "Admins can view all projects"
ON public.projects FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
);

-- Recreate site manager policy with soft delete filter
CREATE POLICY "Site managers can view assigned projects"
ON public.projects FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND id IN (
        SELECT project_id FROM public.project_assignments
        WHERE user_id = auth.uid()
    )
);

-- ============================================================
-- PART 3: GET PROJECT STATS RPC FUNCTION
-- Returns material, labor, machinery counts for a project
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_project_stats(p_project_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    material_received INT := 0;
    material_consumed INT := 0;
    labor_count INT := 0;
    machinery_count INT := 0;
    blueprint_count INT := 0;
BEGIN
    -- Count materials (from stock_items)
    SELECT 
        COALESCE(SUM(CASE WHEN entry_type = 'received' THEN quantity ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN entry_type = 'consumed' THEN quantity ELSE 0 END), 0)
    INTO material_received, material_consumed
    FROM public.stock_items
    WHERE project_id = p_project_id;

    -- Count active labor
    SELECT COUNT(*)
    INTO labor_count
    FROM public.labour
    WHERE project_id = p_project_id
    AND status = 'active';

    -- Count blueprints
    SELECT COUNT(*)
    INTO blueprint_count
    FROM public.blueprints
    WHERE project_id = p_project_id;

    -- Build result JSON
    SELECT json_build_object(
        'material_received', material_received,
        'material_consumed', material_consumed,
        'material_remaining', material_received - material_consumed,
        'labor_count', labor_count,
        'machinery_count', machinery_count,
        'blueprint_count', blueprint_count
    ) INTO result;

    RETURN result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_project_stats TO authenticated;

-- ============================================================
-- PART 4: GET PROJECT MATERIAL BREAKDOWN
-- Returns breakdown by material type (Steel, Cement, etc.)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_project_material_breakdown(p_project_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_agg(material_data)
    INTO result
    FROM (
        SELECT 
            name,
            COALESCE(SUM(CASE WHEN entry_type = 'received' THEN quantity ELSE 0 END), 0) as received,
            COALESCE(SUM(CASE WHEN entry_type = 'consumed' THEN quantity ELSE 0 END), 0) as consumed,
            COALESCE(SUM(CASE WHEN entry_type = 'received' THEN quantity ELSE 0 END), 0) - 
            COALESCE(SUM(CASE WHEN entry_type = 'consumed' THEN quantity ELSE 0 END), 0) as remaining,
            unit
        FROM public.stock_items
        WHERE project_id = p_project_id
        GROUP BY name, unit
        ORDER BY name
    ) as material_data;

    RETURN COALESCE(result, '[]'::JSON);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_project_material_breakdown TO authenticated;

-- ============================================================
-- PART 5: SOFT DELETE FUNCTION
-- Helper function for soft deleting projects
-- ============================================================

CREATE OR REPLACE FUNCTION public.soft_delete_project(p_project_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Check if user is admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    ) THEN
        RAISE EXCEPTION 'Only admins can delete projects';
    END IF;

    -- Perform soft delete
    UPDATE public.projects
    SET deleted_at = NOW(), updated_at = NOW()
    WHERE id = p_project_id AND deleted_at IS NULL;

    -- Log the operation
    PERFORM public.log_operation(
        'delete', 'project', p_project_id,
        'Project deleted',
        NULL,
        p_project_id
    );

    RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.soft_delete_project TO authenticated;

-- ============================================================
-- PART 6: UPDATE PROJECT PROGRESS FUNCTION
-- Updates progress and handles status transitions
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_project_progress(
    p_project_id UUID,
    p_progress INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_status TEXT;
    new_status TEXT;
BEGIN
    -- Get current status
    SELECT status INTO current_status
    FROM public.projects
    WHERE id = p_project_id;

    -- Determine new status based on progress
    new_status := current_status;
    IF p_progress = 100 AND current_status != 'completed' THEN
        new_status := 'completed';
    ELSIF p_progress > 0 AND p_progress < 100 AND current_status = 'planning' THEN
        new_status := 'in_progress';
    END IF;

    -- Update project
    UPDATE public.projects
    SET 
        progress = p_progress,
        status = new_status,
        updated_at = NOW()
    WHERE id = p_project_id;

    RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_project_progress TO authenticated;

-- ============================================================
-- PART 7: ADD INDEXES FOR NEW COLUMNS
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_projects_client_name ON public.projects(client_name);
CREATE INDEX IF NOT EXISTS idx_projects_project_type ON public.projects(project_type);
CREATE INDEX IF NOT EXISTS idx_projects_deleted_at ON public.projects(deleted_at);

-- ============================================================
-- MIGRATION COMPLETE
-- Run in Supabase SQL Editor
-- ============================================================


-- ============================================================
-- 017_filter_deleted_projects.sql
-- ============================================================
-- ============================================================
-- MIGRATION 017: FILTER DELETED PROJECTS
-- Updates dashboard RPCs to ignore soft-deleted projects
-- ============================================================

-- Update get_dashboard_stats to filter deleted projects
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_user_id UUID DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    user_role TEXT;
    accessible_projects UUID[];
BEGIN
    -- Get user role
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = COALESCE(p_user_id, auth.uid());

    -- Get accessible project IDs based on role
    IF user_role IN ('admin', 'super_admin') THEN
        SELECT array_agg(id) INTO accessible_projects 
        FROM public.projects 
        WHERE status != 'cancelled' AND deleted_at IS NULL;
    ELSE
        SELECT array_agg(pa.project_id) INTO accessible_projects
        FROM public.project_assignments pa
        JOIN public.projects p ON pa.project_id = p.id
        WHERE pa.user_id = COALESCE(p_user_id, auth.uid()) AND p.deleted_at IS NULL;
    END IF;

    -- Build stats JSON
    SELECT json_build_object(
        'active_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'in_progress' AND deleted_at IS NULL
        ),
        'total_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[])) AND deleted_at IS NULL
        ),
        'total_workers', (
            SELECT COALESCE(COUNT(*), 0) FROM public.labour 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'active'
        ),
        'low_stock_items', (
            SELECT COUNT(*) FROM public.stock_items 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND quantity <= COALESCE(low_stock_threshold, 10)
        ),
        'pending_reports', (
            SELECT COUNT(*) FROM public.daily_reports 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'pending'
        ),
        'blueprints_count', (
            SELECT COUNT(*) FROM public.blueprints 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND deleted_at IS NULL
        ),
        'growth_percentage', 12.5, -- Placeholder: calculate weekly growth
        'last_updated', NOW()
    ) INTO result;

    RETURN result;
END;
$$;

-- Update get_active_projects_summary to filter deleted projects
CREATE OR REPLACE FUNCTION public.get_active_projects_summary(p_limit INT DEFAULT 3)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    user_role TEXT;
BEGIN
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF user_role IN ('admin', 'super_admin') THEN
        SELECT json_agg(proj) INTO result
        FROM (
            SELECT json_build_object(
                'id', p.id,
                'name', p.name,
                'project_type', p.project_type,
                'status', p.status,
                'progress', COALESCE(p.progress, 0),
                'start_date', p.start_date,
                'end_date', p.end_date,
                'location', p.location
            ) as proj
            FROM public.projects p
            WHERE p.status = 'in_progress' AND p.deleted_at IS NULL
            ORDER BY p.updated_at DESC
            LIMIT p_limit
        ) sub;
    ELSE
        SELECT json_agg(proj) INTO result
        FROM (
            SELECT json_build_object(
                'id', p.id,
                'name', p.name,
                'project_type', p.project_type,
                'status', p.status,
                'progress', COALESCE(p.progress, 0),
                'start_date', p.start_date,
                'end_date', p.end_date,
                'location', p.location
            ) as proj
            FROM public.projects p
            JOIN public.project_assignments pa ON p.id = pa.project_id
            WHERE pa.user_id = auth.uid()
            AND p.status = 'in_progress' AND p.deleted_at IS NULL
            ORDER BY p.updated_at DESC
            LIMIT p_limit
        ) sub;
    END IF;

    RETURN COALESCE(result, '[]'::JSON);
END;
$$;


-- ============================================================
-- 017b_suppliers_table.sql
-- ============================================================
-- ============================================================
-- MIGRATION 017: SUPPLIERS TABLE
-- Vendor management for material procurement
-- ============================================================

-- ============================================================
-- PART 1: CREATE SUPPLIERS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    category TEXT CHECK (category IN ('Cement', 'Steel', 'Sand', 'Aggregate', 'Bricks', 'Electrical', 'Plumbing', 'Hardware', 'Other')),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PART 2: RLS POLICIES FOR SUPPLIERS
-- ============================================================

-- Admins can do everything
CREATE POLICY "Admins can manage suppliers"
ON public.suppliers FOR ALL
TO authenticated
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

-- Site managers can view suppliers
CREATE POLICY "Site managers can view suppliers"
ON public.suppliers FOR SELECT
TO authenticated
USING (
    public.get_my_role() = 'site_manager'
    AND is_active = true
);

-- Site managers can add suppliers
CREATE POLICY "Site managers can add suppliers"
ON public.suppliers FOR INSERT
TO authenticated
WITH CHECK (public.get_my_role() = 'site_manager');

-- ============================================================
-- PART 3: ADD SUPPLIER_ID TO MATERIAL_LOGS
-- ============================================================

ALTER TABLE public.material_logs 
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;

-- Create index for supplier lookup
CREATE INDEX IF NOT EXISTS idx_material_logs_supplier 
ON public.material_logs(supplier_id);

-- ============================================================
-- PART 4: INDEXES FOR SUPPLIERS
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_suppliers_name ON public.suppliers(name);
CREATE INDEX IF NOT EXISTS idx_suppliers_category ON public.suppliers(category);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_active ON public.suppliers(is_active);

-- ============================================================
-- PART 5: UPDATED_AT TRIGGER
-- ============================================================

DROP TRIGGER IF EXISTS update_suppliers_updated_at ON public.suppliers;
CREATE TRIGGER update_suppliers_updated_at
    BEFORE UPDATE ON public.suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- MIGRATION COMPLETE
-- Run in Supabase SQL Editor
-- ============================================================


-- ============================================================
-- 018_fix_architecture_issues.sql
-- ============================================================
-- ============================================================
-- MIGRATION 018: FIX ARCHITECTURE ISSUES
-- Fixes bugs in RPC functions, adds missing columns/tables
-- ============================================================

-- ============================================================
-- PART 1: ADD STATUS TO DAILY_REPORTS
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'daily_reports' 
        AND column_name = 'status'
    ) THEN
        ALTER TABLE public.daily_reports 
        ADD COLUMN status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed'));
        RAISE NOTICE 'Added status column to daily_reports';
    END IF;
END $$;

-- ============================================================
-- PART 2: CREATE MACHINERY_LOGS TABLE
-- ============================================================

-- Create machinery table if it doesn't exist (it should have been in 001, but apparently missing)
CREATE TABLE IF NOT EXISTS public.machinery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT,
    registration_number TEXT,
    status TEXT DEFAULT 'available' CHECK (status IN ('available', 'in_use', 'maintenance', 'retired')),
    hourly_rate DECIMAL(10, 2),
    current_project_id UUID REFERENCES public.projects(id),
    created_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for machinery if valid
ALTER TABLE public.machinery ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for machinery if missing
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins can manage machinery' AND tablename = 'machinery') THEN
        CREATE POLICY "Admins can manage machinery"
            ON public.machinery FOR ALL
            USING (public.is_admin_or_super());
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Site managers can view machinery' AND tablename = 'machinery') THEN
        CREATE POLICY "Site managers can view machinery"
            ON public.machinery FOR SELECT
            USING (
                current_project_id IS NULL
                OR
                EXISTS (
                    SELECT 1 FROM public.project_assignments
                    WHERE project_id = machinery.current_project_id AND user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- Drop table if it exists to ensure clean slate (in case of partial migrations)
DROP TABLE IF EXISTS public.machinery_logs;

CREATE TABLE IF NOT EXISTS public.machinery_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    machinery_id UUID NOT NULL REFERENCES public.machinery(id) ON DELETE CASCADE,
    log_type TEXT CHECK (log_type IN ('usage', 'maintenance', 'breakdown', 'fuel')),
    hours_used DECIMAL(10, 2),
    notes TEXT,
    logged_by UUID REFERENCES auth.users(id),
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.machinery_logs ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_machinery_logs_project ON public.machinery_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_machinery_logs_machinery ON public.machinery_logs(machinery_id);
CREATE INDEX IF NOT EXISTS idx_machinery_logs_date ON public.machinery_logs(logged_at DESC);

-- RLS Policies
-- Drop existing policies if any
DROP POLICY IF EXISTS "Admins can manage machinery logs" ON public.machinery_logs;
DROP POLICY IF EXISTS "Site managers can view project machinery logs" ON public.machinery_logs;
DROP POLICY IF EXISTS "Site managers can add project machinery logs" ON public.machinery_logs;

-- Admins full access
CREATE POLICY "Admins can manage machinery logs"
ON public.machinery_logs FOR ALL
USING (public.is_admin_or_super())
WITH CHECK (public.is_admin_or_super());

-- Site managers view access
CREATE POLICY "Site managers can view project machinery logs"
ON public.machinery_logs FOR SELECT
USING (public.is_assigned_to_project(project_id));

-- Site managers insert access
CREATE POLICY "Site managers can add project machinery logs"
ON public.machinery_logs FOR INSERT
WITH CHECK (public.is_assigned_to_project(project_id));

-- ============================================================
-- PART 3: FIX GET_PROJECT_STATS (Bug Fix)
-- Previously referenced non-existent columns on stock_items
-- Now uses material_logs for received/consumed counts
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_project_stats(p_project_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    material_received INT := 0;
    material_consumed INT := 0;
    labor_count INT := 0;
    machinery_count INT := 0;
    blueprint_count INT := 0;
BEGIN
    -- Calculate materials from material_logs
    -- Inward logs = received
    SELECT COALESCE(SUM(quantity), 0)
    INTO material_received
    FROM public.material_logs
    WHERE project_id = p_project_id
    AND log_type = 'inward';

    -- Outward logs = consumed
    SELECT COALESCE(SUM(quantity), 0)
    INTO material_consumed
    FROM public.material_logs
    WHERE project_id = p_project_id
    AND log_type = 'outward';

    -- Count active labor
    SELECT COUNT(*)
    INTO labor_count
    FROM public.labour
    WHERE project_id = p_project_id
    AND status = 'active';

    -- Count machinery assigned to project
    SELECT COUNT(*)
    INTO machinery_count
    FROM public.machinery
    WHERE current_project_id = p_project_id;

    -- Count blueprints
    SELECT COUNT(*)
    INTO blueprint_count
    FROM public.blueprints
    WHERE project_id = p_project_id;

    -- Build result JSON
    SELECT json_build_object(
        'material_received', material_received,
        'material_consumed', material_consumed,
        'material_remaining', material_received - material_consumed,
        'labor_count', labor_count,
        'machinery_count', machinery_count,
        'blueprint_count', blueprint_count
    ) INTO result;

    RETURN result;
END;
$$;

-- ============================================================
-- PART 4: FIX GET_PROJECT_MATERIAL_BREAKDOWN (Bug Fix)
-- Previously referenced non-existent columns on stock_items
-- Now uses material_logs joined with stock_items
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_project_material_breakdown(p_project_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_agg(material_data)
    INTO result
    FROM (
        SELECT 
            s.name,
            -- Sum inward logs for received
            COALESCE(SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END), 0) as received,
            -- Sum outward logs for consumed
            COALESCE(SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END), 0) as consumed,
            -- Calculate remaining
            COALESCE(SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END), 0) - 
            COALESCE(SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END), 0) as remaining,
            s.unit
        FROM public.stock_items s
        LEFT JOIN public.material_logs ml ON s.id = ml.item_id
        WHERE s.project_id = p_project_id
        GROUP BY s.id, s.name, s.unit
        HAVING 
            COALESCE(SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END), 0) > 0 OR
            COALESCE(SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END), 0) > 0
        ORDER BY s.name
    ) as material_data;

    RETURN COALESCE(result, '[]'::JSON);
END;
$$;

-- ============================================================
-- PART 5: FIX GET_DASHBOARD_STATS
-- Ensure it uses the new status column on daily_reports
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_user_id UUID DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    user_role TEXT;
    accessible_projects UUID[];
BEGIN
    -- Get user role
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = COALESCE(p_user_id, auth.uid());

    -- Get accessible project IDs based on role
    IF user_role IN ('admin', 'super_admin') THEN
        SELECT array_agg(id) INTO accessible_projects FROM public.projects WHERE status != 'cancelled';
    ELSE
        SELECT array_agg(project_id) INTO accessible_projects
        FROM public.project_assignments
        WHERE user_id = COALESCE(p_user_id, auth.uid());
    END IF;

    -- Build stats JSON
    SELECT json_build_object(
        'active_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'in_progress'
        ),
        'total_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
        ),
        'total_workers', (
            SELECT COALESCE(COUNT(*), 0) FROM public.labour 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'active'
        ),
        'low_stock_items', (
            SELECT COUNT(*) FROM public.stock_items 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND quantity <= COALESCE(low_stock_threshold, 10)
        ),
        'pending_reports', (
            SELECT COUNT(*) FROM public.daily_reports 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'pending'
        ),
        'blueprints_count', (
            SELECT COUNT(*) FROM public.blueprints 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
        ),
        'growth_percentage', 12.5, -- Placeholder
        'last_updated', NOW()
    ) INTO result;

    RETURN result;
END;
$$;

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================


-- ============================================================
-- 019_dynamic_dashboard.sql
-- ============================================================
-- ============================================================
-- MIGRATION 019: DYNAMIC DASHBOARD & REAL-TIME
-- Adds triggers for progress calculation and improved stats
-- ============================================================

-- ============================================================
-- PART 1: DYNAMIC PROJECT PROGRESS
-- Calculates progress based on budget vs expenses (Bills)
-- ============================================================

CREATE OR REPLACE FUNCTION public.calculate_project_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_project_id UUID;
    v_total_budget DECIMAL;
    v_total_expenses DECIMAL;
    v_progress INTEGER;
BEGIN
    -- Determine project_id based on operation
    IF TG_OP = 'DELETE' THEN
        v_project_id := OLD.project_id;
    ELSE
        v_project_id := NEW.project_id;
    END IF;

    -- Get project budget
    SELECT budget INTO v_total_budget
    FROM public.projects
    WHERE id = v_project_id;

    -- If no budget set, default to 0 progress or keep manual
    IF v_total_budget IS NULL OR v_total_budget <= 0 THEN
        RETURN NULL;
    END IF;

    -- Calculate total approved expenses
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
    FROM public.bills
    WHERE project_id = v_project_id
    AND status IN ('approved', 'paid')
    AND bill_type = 'expense';

    -- Calculate percentage (capped at 100)
    v_progress := LEAST(FLOOR((v_total_expenses / v_total_budget) * 100), 100);

    -- Update project progress
    UPDATE public.projects
    SET progress = v_progress,
        updated_at = NOW()
    WHERE id = v_project_id;

    RETURN NULL;
END;
$$;

-- Trigger for Bills changes
DROP TRIGGER IF EXISTS trigger_update_project_progress ON public.bills;
CREATE TRIGGER trigger_update_project_progress
AFTER INSERT OR UPDATE OR DELETE ON public.bills
FOR EACH ROW EXECUTE FUNCTION public.calculate_project_progress();

-- ============================================================
-- PART 2: IMPROVED DASHBOARD STATS
-- Adds dynamic growth calculation
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_user_id UUID DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
    user_role TEXT;
    accessible_projects UUID[];
    v_current_week_logs INTEGER;
    v_last_week_logs INTEGER;
    v_growth_rate DECIMAL;
BEGIN
    -- Get user role
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = COALESCE(p_user_id, auth.uid());

    -- Get accessible project IDs based on role
    IF user_role IN ('admin', 'super_admin') THEN
        SELECT array_agg(id) INTO accessible_projects FROM public.projects WHERE status != 'cancelled';
    ELSE
        SELECT array_agg(project_id) INTO accessible_projects
        FROM public.project_assignments
        WHERE user_id = COALESCE(p_user_id, auth.uid());
    END IF;

    -- Calculate Growth: Compare operation logs count (This week vs Last week)
    -- This gives a sense of "Activity Growth"
    SELECT COUNT(*) INTO v_current_week_logs
    FROM public.operation_logs
    WHERE created_at >= date_trunc('week', CURRENT_DATE)
    AND (project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[])) OR project_id IS NULL);

    SELECT COUNT(*) INTO v_last_week_logs
    FROM public.operation_logs
    WHERE created_at >= date_trunc('week', CURRENT_DATE - INTERVAL '1 week')
    AND created_at < date_trunc('week', CURRENT_DATE)
    AND (project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[])) OR project_id IS NULL);

    IF v_last_week_logs > 0 THEN
        v_growth_rate := ((v_current_week_logs::DECIMAL - v_last_week_logs::DECIMAL) / v_last_week_logs::DECIMAL) * 100;
    ELSE
        v_growth_rate := 100.0; -- 100% growth if starting from 0
    END IF;

    -- Build stats JSON
    SELECT json_build_object(
        'active_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'in_progress'
        ),
        'total_projects', (
            SELECT COUNT(*) FROM public.projects 
            WHERE id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
        ),
        'total_workers', (
            SELECT COALESCE(COUNT(*), 0) FROM public.labour 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'active'
        ),
        'low_stock_items', (
            SELECT COUNT(*) FROM public.stock_items 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND quantity <= COALESCE(low_stock_threshold, 10)
        ),
        'pending_reports', (
            SELECT COUNT(*) FROM public.daily_reports 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
            AND status = 'pending'
        ),
        'blueprints_count', (
            SELECT COUNT(*) FROM public.blueprints 
            WHERE project_id = ANY(COALESCE(accessible_projects, ARRAY[]::UUID[]))
        ),
        'growth_percentage', ROUND(v_growth_rate, 1),
        'last_updated', NOW()
    ) INTO result;

    RETURN result;
END;
$$;


-- ============================================================
-- 020_reports_schema.sql
-- ============================================================
-- Migration: Reports Schema
-- Description: Adds views and functions for the Insights/Reports module

-- ============================================================
-- 1. Financial Summary View
-- Aggregates approved expenses by month and project
-- ============================================================

CREATE OR REPLACE VIEW public.v_financial_summary AS
SELECT
    DATE_TRUNC('month', created_at)::DATE AS period,
    project_id,
    bill_type,
    SUM(amount) AS total_amount
FROM
    public.bills
WHERE
    status IN ('approved', 'paid')
GROUP BY
    1, 2, 3;

-- ============================================================
-- 2. Resource Usage View
-- Aggregates costs by resource type (Labor, Material, Machinery)
-- ============================================================

CREATE OR REPLACE VIEW public.v_resource_usage AS
SELECT
    project_id,
    bill_type AS resource_type,
    SUM(amount) AS total_cost
FROM
    public.bills
WHERE
    status IN ('approved', 'paid')
GROUP BY
    1, 2;

-- ============================================================
-- 3. Get Financial Metrics RPC
-- Returns aggregated stats for charts and cards
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_financial_metrics(
    p_period TEXT DEFAULT 'monthly', -- 'monthly', 'quarterly', 'yearly'
    p_project_id_text TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    p_project_id UUID := NULL;
    v_start_date DATE;
    v_prev_start_date DATE;
    v_end_date DATE := CURRENT_DATE;
    
    v_total_expenses DECIMAL := 0;
    v_prev_total_expenses DECIMAL := 0;
    v_growth_rate DECIMAL := 0;
    
    v_labor_cost DECIMAL := 0;
    v_material_cost DECIMAL := 0;
    v_machinery_cost DECIMAL := 0;
    v_other_cost DECIMAL := 0;
    
    v_chart_data JSON;
BEGIN
    -- Cast project_id from text to UUID if provided
    IF p_project_id_text IS NOT NULL THEN
        p_project_id := p_project_id_text::UUID;
    END IF;

    -- Determine date range based on period
    CASE p_period
        WHEN 'yearly' THEN
            v_start_date := DATE_TRUNC('year', CURRENT_DATE);
            v_prev_start_date := DATE_TRUNC('year', CURRENT_DATE - INTERVAL '1 year');
        WHEN 'quarterly' THEN
            v_start_date := DATE_TRUNC('quarter', CURRENT_DATE);
            v_prev_start_date := DATE_TRUNC('quarter', CURRENT_DATE - INTERVAL '3 months');
        ELSE -- monthly
            v_start_date := DATE_TRUNC('month', CURRENT_DATE);
            v_prev_start_date := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month');
    END CASE;

    -- Calculate Totals
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
    FROM public.bills
    WHERE status IN ('approved', 'paid')
    AND created_at >= v_start_date
    AND (p_project_id IS NULL OR project_id = p_project_id);

    -- Calculate Previous Period Totals (for Growth %)
    SELECT COALESCE(SUM(amount), 0) INTO v_prev_total_expenses
    FROM public.bills
    WHERE status IN ('approved', 'paid')
    AND created_at >= v_prev_start_date
    AND created_at < v_start_date
    AND (p_project_id IS NULL OR project_id = p_project_id);

    -- Calculate Growth %
    IF v_prev_total_expenses > 0 THEN
        v_growth_rate := ((v_total_expenses - v_prev_total_expenses) / v_prev_total_expenses) * 100;
    ELSE
        v_growth_rate := 0;
    END IF;

    -- Calculate Resource Split
    SELECT 
        COALESCE(SUM(CASE WHEN bill_type = 'labour' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN bill_type = 'material' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN bill_type = 'machinery' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN bill_type NOT IN ('labour', 'material', 'machinery') THEN amount ELSE 0 END), 0)
    INTO v_labor_cost, v_material_cost, v_machinery_cost, v_other_cost
    FROM public.bills
    WHERE status IN ('approved', 'paid')
    AND (p_project_id IS NULL OR project_id = p_project_id);

    -- Get Chart Data (Expenses over time)
    -- Grouping depends on selected period
    WITH chart_series AS (
        SELECT
            TO_CHAR(created_at, CASE 
                WHEN p_period = 'yearly' THEN 'Mon' 
                ELSE 'DD Mon' 
            END) AS label,
            SUM(amount) as value,
            MIN(created_at) as sort_date
        FROM public.bills
        WHERE status IN ('approved', 'paid')
        AND created_at >= CASE 
            WHEN p_period = 'yearly' THEN DATE_TRUNC('year', CURRENT_DATE)
            ELSE DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months') -- Show last 6 months trend for monthly view
        END
        AND (p_project_id IS NULL OR project_id = p_project_id)
        GROUP BY 1
        ORDER BY MIN(created_at)
    )
    SELECT json_agg(row_to_json(chart_series)) INTO v_chart_data FROM chart_series;

    -- Return Result
    RETURN json_build_object(
        'total_expenses', v_total_expenses,
        'growth_percentage', ROUND(v_growth_rate, 1),
        'labor_cost', v_labor_cost,
        'material_cost', v_material_cost,
        'machinery_cost', v_machinery_cost,
        'other_cost', v_other_cost,
        'chart_data', COALESCE(v_chart_data, '[]'::json)
    );
END;
$$;


-- ============================================================
-- 021_fix_bills_relations.sql
-- ============================================================
-- ============================================================
-- FIX BILLS TABLE RELATIONSHIPS AND RLS
-- ============================================================

-- Step 1: Ensure bills table has correct foreign keys
DO $$
BEGIN
    -- Drop existing constraints if they exist (to recreate properly)
    ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_created_by_fkey;
    ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_created_by_fkey1;
    ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_approved_by_fkey;
    ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_approved_by_fkey1;
    ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_project_id_fkey;
    
    -- Recreate with proper references
    ALTER TABLE public.bills 
        ADD CONSTRAINT bills_project_id_fkey 
        FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;
    
    ALTER TABLE public.bills 
        ADD CONSTRAINT bills_created_by_fkey 
        FOREIGN KEY (created_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
    
    ALTER TABLE public.bills 
        ADD CONSTRAINT bills_approved_by_fkey 
        FOREIGN KEY (approved_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
        
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error updating constraints: %', SQLERRM;
END $$;

-- Step 2: Add missing columns if they don't exist
DO $$
BEGIN
    -- Add raised_by column (maps to created_by conceptually)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bills' AND column_name = 'raised_by'
    ) THEN
        ALTER TABLE public.bills ADD COLUMN raised_by UUID REFERENCES public.user_profiles(id);
    END IF;
    
    -- Add bill_type variations needed by the app
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bills' AND column_name = 'payment_type'
    ) THEN
        ALTER TABLE public.bills ADD COLUMN payment_type TEXT 
            CHECK (payment_type IN ('cash', 'upi', 'bank_transfer', 'cheque'));
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bills' AND column_name = 'payment_status'
    ) THEN
        ALTER TABLE public.bills ADD COLUMN payment_status TEXT DEFAULT 'need_to_pay'
            CHECK (payment_status IN ('need_to_pay', 'advance', 'half_paid', 'full_paid'));
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bills' AND column_name = 'approved_at'
    ) THEN
        ALTER TABLE public.bills ADD COLUMN approved_at TIMESTAMPTZ;
    END IF;
END $$;

-- Step 3: Update bill_type constraint to match app requirements
ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_bill_type_check;
ALTER TABLE public.bills ADD CONSTRAINT bills_bill_type_check 
    CHECK (bill_type IN ('workers', 'materials', 'transport', 'equipment_rent', 'expense', 'income', 'invoice'));

-- Step 4: Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_bills_project_id ON public.bills(project_id);
CREATE INDEX IF NOT EXISTS idx_bills_created_by ON public.bills(created_by);
CREATE INDEX IF NOT EXISTS idx_bills_status ON public.bills(status);
CREATE INDEX IF NOT EXISTS idx_bills_created_at ON public.bills(created_at DESC);

-- Step 5: Fix RLS Policies for Bills
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage bills" ON public.bills;
DROP POLICY IF EXISTS "Site managers can manage project bills" ON public.bills;
DROP POLICY IF EXISTS "Strict Project Isolation for Bills" ON public.bills;

-- Admins can do everything
CREATE POLICY "Admins can manage all bills"
    ON public.bills FOR ALL
    USING (public.is_admin_or_super())
    WITH CHECK (public.is_admin_or_super());

-- Site managers can view bills for their assigned projects
CREATE POLICY "Site managers can view project bills"
    ON public.bills FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = bills.project_id AND user_id = auth.uid()
        )
    );

-- Site managers can create bills for their assigned projects
CREATE POLICY "Site managers can create project bills"
    ON public.bills FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = bills.project_id AND user_id = auth.uid()
        )
    );

-- Site managers can update their own pending bills
CREATE POLICY "Site managers can update own pending bills"
    ON public.bills FOR UPDATE
    USING (
        status = 'pending' AND
        created_by = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = bills.project_id AND user_id = auth.uid()
        )
    );

-- Step 6: IMPORTANT - Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 022_atomic_functions.sql
-- ============================================================
-- ============================================================
-- HELPER FUNCTIONS FOR ATOMIC OPERATIONS
-- ============================================================

-- Function to update stock quantity atomically
CREATE OR REPLACE FUNCTION update_stock_quantity(
    p_item_id UUID,
    p_quantity DECIMAL,
    p_operation TEXT -- 'add' or 'subtract'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_operation = 'add' THEN
        UPDATE stock_items 
        SET quantity = quantity + p_quantity,
            updated_at = NOW()
        WHERE id = p_item_id;
    ELSIF p_operation = 'subtract' THEN
        UPDATE stock_items 
        SET quantity = GREATEST(0, quantity - p_quantity),
            updated_at = NOW()
        WHERE id = p_item_id;
    END IF;
END;
$$;

-- Function to increment machinery hours
CREATE OR REPLACE FUNCTION increment_machinery_hours(
    p_machinery_id UUID,
    p_hours DECIMAL
)
RETURNS DECIMAL
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_total DECIMAL;
BEGIN
    UPDATE machinery 
    SET total_hours = total_hours + p_hours,
        updated_at = NOW()
    WHERE id = p_machinery_id
    RETURNING total_hours INTO new_total;
    
    RETURN new_total;
END;
$$;

-- Function to get project-specific stats
CREATE OR REPLACE FUNCTION get_project_stats(p_project_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_stock_items', (SELECT COUNT(*) FROM stock_items WHERE project_id = p_project_id),
        'total_labour', (SELECT COUNT(*) FROM labour WHERE project_id = p_project_id AND status = 'active'),
        'material_inward', (
            SELECT COALESCE(SUM(quantity), 0) 
            FROM material_logs 
            WHERE project_id = p_project_id AND log_type = 'inward'
        ),
        'material_outward', (
            SELECT COALESCE(SUM(quantity), 0) 
            FROM material_logs 
            WHERE project_id = p_project_id AND log_type = 'outward'
        ),
        'pending_bills', (SELECT COUNT(*) FROM bills WHERE project_id = p_project_id AND status = 'pending'),
        'total_bill_amount', (
            SELECT COALESCE(SUM(amount), 0) 
            FROM bills 
            WHERE project_id = p_project_id AND status IN ('approved', 'paid')
        )
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_stock_quantity TO authenticated;
GRANT EXECUTE ON FUNCTION increment_machinery_hours TO authenticated;
GRANT EXECUTE ON FUNCTION get_project_stats TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 023_machinery_tables.sql
-- ============================================================
-- ============================================================
-- MACHINERY AND MACHINERY LOGS TABLES
-- ============================================================

-- Create machinery table if not exists
CREATE TABLE IF NOT EXISTS public.machinery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT, -- Excavator, Crane, Mixer, etc.
    registration_no TEXT UNIQUE,
    current_reading DECIMAL(10,2) DEFAULT 0,
    total_hours DECIMAL(10,2) DEFAULT 0,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'idle', 'retired')),
    purchase_date DATE,
    last_service DATE,
    current_project_id UUID REFERENCES public.projects(id), -- Tracks which project explicitly has it
    created_by UUID REFERENCES public.user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create machinery_logs table if not exists
CREATE TABLE IF NOT EXISTS public.machinery_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    machinery_id UUID NOT NULL REFERENCES public.machinery(id) ON DELETE CASCADE,
    work_activity TEXT NOT NULL,
    start_reading DECIMAL(10,2) NOT NULL,
    end_reading DECIMAL(10,2) NOT NULL,
    execution_hours DECIMAL(10,2) GENERATED ALWAYS AS (end_reading - start_reading) STORED,
    notes TEXT,
    logged_by UUID REFERENCES public.user_profiles(id),
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.machinery ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machinery_logs ENABLE ROW LEVEL SECURITY;

-- Machinery policies (global resource, but logs are project-specific)
DROP POLICY IF EXISTS "Everyone can view machinery" ON public.machinery;
CREATE POLICY "Everyone can view machinery"
    ON public.machinery FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Admins can manage machinery" ON public.machinery;
CREATE POLICY "Admins can manage machinery"
    ON public.machinery FOR ALL
    USING (public.is_admin_or_super())
    WITH CHECK (public.is_admin_or_super());

-- Machinery logs policies
DROP POLICY IF EXISTS "Admins can manage all machinery logs" ON public.machinery_logs;
CREATE POLICY "Admins can manage all machinery logs"
    ON public.machinery_logs FOR ALL
    USING (public.is_admin_or_super())
    WITH CHECK (public.is_admin_or_super());

DROP POLICY IF EXISTS "Site managers can view project machinery logs" ON public.machinery_logs;
CREATE POLICY "Site managers can view project machinery logs"
    ON public.machinery_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = machinery_logs.project_id AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Site managers can create project machinery logs" ON public.machinery_logs;
CREATE POLICY "Site managers can create project machinery logs"
    ON public.machinery_logs FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = machinery_logs.project_id AND user_id = auth.uid()
        )
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_machinery_logs_project ON public.machinery_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_machinery_logs_machinery ON public.machinery_logs(machinery_id);
CREATE INDEX IF NOT EXISTS idx_machinery_status ON public.machinery(status);

-- Refresh schema
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 024_daily_labour_logs.sql
-- ============================================================
CREATE TABLE IF NOT EXISTS public.daily_labour_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    contractor_name TEXT NOT NULL,
    skilled_count INTEGER DEFAULT 0,
    unskilled_count INTEGER DEFAULT 0,
    log_date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.user_profiles(id)
);

ALTER TABLE public.daily_labour_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Site managers can view project labour logs"
    ON public.daily_labour_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = daily_labour_logs.project_id AND user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

CREATE POLICY "Site managers can insert project labour logs"
    ON public.daily_labour_logs FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = दैनिक_labour_logs.project_id AND user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );
-- Typo in table name above fixed in policy below
DROP POLICY IF EXISTS "Site managers can insert project labour logs" ON public.daily_labour_logs;

CREATE POLICY "Site managers can insert project labour logs"
    ON public.daily_labour_logs FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id =Daily_labour_logs.project_id AND user_id = auth.uid()
        )
         OR
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- Wait, I manually typed naming. I should be careful.
-- Correcting:
DROP POLICY IF EXISTS "Site managers can insert project labour logs" ON public.daily_labour_logs;

CREATE POLICY "Site managers can manage project labour logs"
    ON public.daily_labour_logs FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.project_assignments
            WHERE project_id = daily_labour_logs.project_id AND user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );


-- ============================================================
-- 025_fix_blueprint_trigger.sql
-- ============================================================
-- Fix log_blueprint_upload trigger function to use correct columns
-- Previously referenced 'title' and 'version' which were dropped

CREATE OR REPLACE FUNCTION public.log_blueprint_upload()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM public.log_operation(
        'upload', 'blueprint', NEW.id,
        'Blueprint uploaded: ' || NEW.file_name,
        'Folder: ' || COALESCE(NEW.folder_name, 'General'),
        NEW.project_id
    );
    RETURN NEW;
END;
$$;


-- ============================================================
-- 026_vendor_material_totals.sql
-- ============================================================
-- Vendor material aggregation & index

-- 1) Index to speed supplier lookups
CREATE INDEX IF NOT EXISTS idx_material_logs_supplier
ON public.material_logs (supplier_id, project_id, log_type);

-- 2) Helper: check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO authenticated;

-- 3) RPC: vendor material totals (per project, optionally per material)
CREATE OR REPLACE FUNCTION public.get_vendor_material_totals(
  p_vendor_id UUID,
  p_material_name TEXT DEFAULT NULL
)
RETURNS TABLE (
  project_id UUID,
  project_name TEXT,
  material_name TEXT,
  total_inward NUMERIC,
  total_outward NUMERIC,
  net NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH scoped_projects AS (
    SELECT id, name FROM public.projects
    WHERE deleted_at IS NULL
      AND (
        public.is_admin_or_super() OR
        id IN (SELECT project_id FROM public.project_assignments WHERE user_id = auth.uid())
      )
  ),
  base AS (
    SELECT 
      ml.project_id AS proj_id,
      sp.name AS proj_name,
      COALESCE(si.name, 'Unknown') AS mat_name,
      SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END) AS total_inward,
      SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END) AS total_outward
    FROM public.material_logs ml
    JOIN scoped_projects sp ON sp.id = ml.project_id
    LEFT JOIN public.stock_items si ON si.id = ml.item_id
    WHERE ml.supplier_id = p_vendor_id
      AND (p_material_name IS NULL OR lower(COALESCE(si.name, '')) = lower(p_material_name))
    GROUP BY ml.project_id, sp.name, COALESCE(si.name, 'Unknown')
  )
  SELECT 
    base.proj_id AS project_id,
    base.proj_name AS project_name,
    base.mat_name AS material_name,
    base.total_inward,
    base.total_outward,
    base.total_inward - base.total_outward AS net
  FROM base
  ORDER BY base.proj_name, base.mat_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_vendor_material_totals(UUID, TEXT) TO authenticated;

-- 4) RPC: vendor overview (admin-only, aggregates across all projects)
CREATE OR REPLACE FUNCTION public.get_vendor_overview()
RETURNS TABLE (
  vendor_id UUID,
  vendor_name TEXT,
  total_qty NUMERIC
) AS $$
BEGIN
  IF NOT public.is_admin_or_super() THEN
    RAISE EXCEPTION 'Only admins can access vendor overview';
  END IF;

  RETURN QUERY
  SELECT 
    v.id,
    v.name,
    COALESCE(SUM(ml.quantity), 0) AS total_qty
  FROM public.suppliers v
  LEFT JOIN public.material_logs ml ON ml.supplier_id = v.id AND ml.log_type = 'inward'
  GROUP BY v.id, v.name
  ORDER BY total_qty DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_vendor_overview() TO authenticated;


-- ============================================================
-- 027_add_labour_id_to_daily_labour_logs.sql
-- ============================================================
-- Add optional labour_id to daily_labour_logs for linking master labour
ALTER TABLE public.daily_labour_logs
ADD COLUMN IF NOT EXISTS labour_id UUID REFERENCES public.labour(id);

-- Index for lookups by labour/project
CREATE INDEX IF NOT EXISTS idx_daily_labour_logs_labour ON public.daily_labour_logs(labour_id);
CREATE INDEX IF NOT EXISTS idx_daily_labour_logs_project ON public.daily_labour_logs(project_id);


-- ============================================================
-- 028_labour_master_nullable.sql
-- ============================================================
-- Allow labour.project_id to be NULL so we can store master labour records
ALTER TABLE public.labour
  ALTER COLUMN project_id DROP NOT NULL;

-- Update site manager policy to allow reading master (project_id IS NULL) and keep project-scoped access
DROP POLICY IF EXISTS "Site managers can manage project labour" ON public.labour;
CREATE POLICY "Site managers can manage project labour"
    ON public.labour FOR ALL
    USING (
      project_id IS NULL OR
      EXISTS (
        SELECT 1 FROM public.project_assignments
        WHERE project_id = labour.project_id AND user_id = auth.uid()
      )
    )
    WITH CHECK (
      project_id IS NULL OR
      EXISTS (
        SELECT 1 FROM public.project_assignments
        WHERE project_id = labour.project_id AND user_id = auth.uid()
      )
    );

-- Keep admin policy as-is (full access), no change needed

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 029_bills_replica_identity.sql
-- ============================================================
-- Ensure bills realtime uses full row data
ALTER TABLE public.bills REPLICA IDENTITY FULL;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 030_material_operations.sql
-- ============================================================
-- =============================================================================
-- MATERIAL OPERATIONS - MASTER TABLES & DYNAMIC STOCK MIGRATION
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. MASTER TABLES (Global suggestions)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.material_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.material_grades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id UUID REFERENCES public.material_master(id) ON DELETE CASCADE,
  grade_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(material_id, grade_name)
);

-- Enable RLS
ALTER TABLE public.material_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_grades ENABLE ROW LEVEL SECURITY;

-- Policies for Master Tables (Viewable by all authenticated, manageable by Admin)
CREATE POLICY "Authenticated users can view material master"
  ON public.material_master FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage material master"
  ON public.material_master FOR ALL TO authenticated
  USING (public.is_admin_or_super());

CREATE POLICY "Authenticated users can view material grades"
  ON public.material_grades FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage material grades"
  ON public.material_grades FOR ALL TO authenticated
  USING (public.is_admin_or_super());

-- Users (Site Managers) can also insert new suggestions implicitly? 
-- The user request says "Add new material" is allowed. 
-- Let's allow authenticated users to INSERT into master if it doesn't exist.
CREATE POLICY "Authenticated users can insert material master"
  ON public.material_master FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can insert material grades"
  ON public.material_grades FOR INSERT TO authenticated
  WITH CHECK (true);


-- -----------------------------------------------------------------------------
-- 2. DYNAMIC STOCK BALANCE VIEW
-- -----------------------------------------------------------------------------
-- Ensure stock_items has project_id NOT NULL if not already
ALTER TABLE public.stock_items ALTER COLUMN project_id SET NOT NULL;

-- Dynamic view replacing the static balance logic
CREATE OR REPLACE VIEW public.v_stock_balance_dynamic AS
SELECT 
  s.id AS item_id,
  s.project_id,
  s.name,
  s.grade,
  s.unit,
  s.low_stock_threshold,
  s.category,
  -- Dynamic calculation
  COALESCE(received.total, 0) AS total_received,
  COALESCE(consumed.total, 0) AS total_consumed,
  (COALESCE(received.total, 0) - COALESCE(consumed.total, 0)) AS current_stock,
  CASE 
    WHEN (COALESCE(received.total, 0) - COALESCE(consumed.total, 0)) <= s.low_stock_threshold THEN true 
    ELSE false 
  END AS is_low_stock
FROM public.stock_items s
LEFT JOIN (
  SELECT item_id, SUM(quantity) AS total
  FROM public.material_logs
  WHERE log_type = 'inward'
  GROUP BY item_id
) received ON received.item_id = s.id
LEFT JOIN (
  SELECT item_id, SUM(quantity) AS total
  FROM public.material_logs
  WHERE log_type = 'outward'
  GROUP BY item_id
) consumed ON consumed.item_id = s.id;

-- -----------------------------------------------------------------------------
-- 3. UPDATED LOGGING FUNCTIONS & TRIGGERS
-- -----------------------------------------------------------------------------

-- Helper to ensure stock item exists before logging (Idempotent Get-or-Create)
CREATE OR REPLACE FUNCTION public.get_or_create_stock_item(
  p_project_id UUID,
  p_name TEXT,
  p_grade TEXT,
  p_unit TEXT
) RETURNS UUID AS $$
DECLARE
  v_item_id UUID;
BEGIN
  -- Check for existing item in project (Name + Grade must be unique per project)
  SELECT id INTO v_item_id
  FROM public.stock_items
  WHERE project_id = p_project_id
    AND name = p_name
    AND COALESCE(grade, '') = COALESCE(p_grade, '');
    
  IF v_item_id IS NULL THEN
    INSERT INTO public.stock_items (project_id, name, grade, unit, quantity, created_by)
    VALUES (p_project_id, p_name, p_grade, p_unit, 0, auth.uid())
    RETURNING id INTO v_item_id;
  END IF;
  
  RETURN v_item_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Validation trigger for Consumptions
CREATE OR REPLACE FUNCTION public.validate_material_consumption()
RETURNS TRIGGER AS $$
DECLARE
  v_current_stock NUMERIC;
BEGIN
  IF NEW.log_type = 'outward' THEN
    -- Calculate current stock for this item
    SELECT current_stock INTO v_current_stock
    FROM public.v_stock_balance_dynamic
    WHERE item_id = NEW.item_id;
    
    IF v_current_stock IS NULL THEN 
       v_current_stock := 0; 
    END IF;
    
    IF NEW.quantity > v_current_stock THEN
      RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', v_current_stock, NEW.quantity;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validate_consumption ON public.material_logs;
CREATE TRIGGER trigger_validate_consumption
  BEFORE INSERT ON public.material_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_material_consumption();

-- Trigger to auto-add to Master tables on new Stock Item creation
CREATE OR REPLACE FUNCTION public.sync_material_master()
RETURNS TRIGGER AS $$
DECLARE
  v_materail_id UUID;
BEGIN
  -- 1. Sync Material Name
  INSERT INTO public.material_master (name)
  VALUES (NEW.name)
  ON CONFLICT (name) DO NOTHING;
  
  SELECT id INTO v_materail_id FROM public.material_master WHERE name = NEW.name;

  -- 2. Sync Grade if present
  IF NEW.grade IS NOT NULL THEN
    INSERT INTO public.material_grades (material_id, grade_name)
    VALUES (v_materail_id, NEW.grade)
    ON CONFLICT (material_id, grade_name) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sync_material_master ON public.stock_items;
CREATE TRIGGER trigger_sync_material_master
  AFTER INSERT ON public.stock_items
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_material_master();

-- -----------------------------------------------------------------------------
-- 4. PERMISSIONS
-- -----------------------------------------------------------------------------

-- Grant access to the view
GRANT SELECT ON public.v_stock_balance_dynamic TO authenticated;

-- Notify schema reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 031_add_material_log_columns.sql
-- ============================================================
-- ============================================================
-- MIGRATION 031: ADD MISSING COLUMNS
-- Adds missing columns to material_logs and stock_items
-- to support material operations code.
-- ============================================================

-- 1. MATERIAL LOGS MISSING COLUMNS
ALTER TABLE public.material_logs 
ADD COLUMN IF NOT EXISTS payment_type TEXT,
ADD COLUMN IF NOT EXISTS bill_amount DECIMAL(15, 2),
ADD COLUMN IF NOT EXISTS grade TEXT;

-- 2. STOCK ITEMS MISSING COLUMNS
-- 'grade' is used in get_or_create_stock_item RPC and Dart code
ALTER TABLE public.stock_items
ADD COLUMN IF NOT EXISTS grade TEXT;

-- 3. FIX PAYMENT TYPE VALUES (To match App Dropdown: Cash, Online, Cheque)
-- If there was a constraint (implicit or explicit), we normalize it.
-- We add a flexible constraint to allow both casing just in case, or match App.
ALTER TABLE public.material_logs DROP CONSTRAINT IF EXISTS material_logs_payment_type_check;

ALTER TABLE public.material_logs 
ADD CONSTRAINT material_logs_payment_type_check 
CHECK (payment_type IN ('Cash', 'Online', 'Cheque', 'cash', 'online', 'cheque', 'UPI', 'Bank Transfer'));

-- Notify schema reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 032_machinery_time_tracking.sql
-- ============================================================
-- ============================================================
-- MIGRATION 032: MACHINERY TIME TRACKING & UPDATES
-- Adds support for time-based logging and ownership type
-- ============================================================

-- 1. Update machinery_logs table
-- We make reading columns nullable because new logs might only use time
ALTER TABLE public.machinery_logs
ALTER COLUMN start_reading DROP NOT NULL,
ALTER COLUMN end_reading DROP NOT NULL;

-- Add new columns for time-based tracking
ALTER TABLE public.machinery_logs
ADD COLUMN IF NOT EXISTS log_date DATE DEFAULT CURRENT_DATE,
ADD COLUMN IF NOT EXISTS start_time TIME,
ADD COLUMN IF NOT EXISTS end_time TIME,
ADD COLUMN IF NOT EXISTS total_hours DECIMAL(10, 2);

-- 2. Update machinery table
-- Add ownership_type as requested
ALTER TABLE public.machinery
ADD COLUMN IF NOT EXISTS ownership_type TEXT CHECK (ownership_type IN ('Own', 'Rental', 'own', 'rental'));

-- 3. Indexes for new columns
CREATE INDEX IF NOT EXISTS idx_machinery_logs_date ON public.machinery_logs(log_date);

-- 4. Validation Trigger (Start Time < End Time)
CREATE OR REPLACE FUNCTION public.validate_machinery_time()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL THEN
    IF NEW.end_time <= NEW.start_time THEN
      RAISE EXCEPTION 'End Time must be after Start Time';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validate_machinery_time ON public.machinery_logs;
CREATE TRIGGER trigger_validate_machinery_time
  BEFORE INSERT OR UPDATE ON public.machinery_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_machinery_time();

-- 5. Helper RPC to increment machinery total hours
CREATE OR REPLACE FUNCTION public.increment_machinery_hours(
  p_machinery_id UUID,
  p_hours DECIMAL
) RETURNS DECIMAL AS $$
DECLARE
  v_new_total DECIMAL;
  v_current_total DECIMAL;
BEGIN
  SELECT total_hours INTO v_current_total FROM public.machinery WHERE id = p_machinery_id;
  
  v_new_total := COALESCE(v_current_total, 0) + p_hours;
  
  UPDATE public.machinery
  SET total_hours = v_new_total
  WHERE id = p_machinery_id;
  
  RETURN v_new_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify schema reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 033_fix_machinery_rls.sql
-- ============================================================
-- Migration 033: Allow Site Managers to Create Machinery
-- The previous policies only allowed Admins to manage machinery master list.
-- This update allows Site Managers to also INSERT into machinery table.

-- Function to check if user is a site manager (has any project assignment)
-- We leverage existing tables. Assuming 'project_assignments' implies site manager role or similar.
-- Or we just allow any authenticated user to create machinery (common in these apps to avoid blocking operations).

-- Let's use a policy that allows INSERT for authenticated users, but UPDATE/DELETE only for Admins (already covering ALL) or Creator.
-- "Admins can manage machinery" handles ALL for admins.

-- New Policy: Users can create machinery
DROP POLICY IF EXISTS "Users can create machinery" ON public.machinery;
CREATE POLICY "Users can create machinery"
    ON public.machinery FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Optional: Allow creators to update their own machinery?
-- For now, just INSERT is the blocker.

NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 034_fix_machinery_schema.sql
-- ============================================================
-- Migration 034: Fix Machinery Schema
-- It appears 'registration_no' is missing from the table, likely because the table 
-- existed before migration 023 was applied, causing the IF NOT EXISTS to skip creation.

ALTER TABLE public.machinery 
ADD COLUMN IF NOT EXISTS registration_no TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS type TEXT;

-- Verify ownership_type is there too (was added in 032, but good to be safe)
ALTER TABLE public.machinery 
ADD COLUMN IF NOT EXISTS ownership_type TEXT CHECK (ownership_type IN ('Own', 'Rental', 'own', 'rental'));

-- Reload schema cache ensuring Supabase picks up the changes
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 035_align_machinery_schema.sql
-- ============================================================
-- Migration 035: Align Machinery Logs Schema
-- User requires 'hours_used' and 'log_type' for usage logging.

-- 1. Add log_type
ALTER TABLE public.machinery_logs 
ADD COLUMN IF NOT EXISTS log_type TEXT DEFAULT 'usage';

-- 2. Add hours_used (User prefers this over total_hours for the log entry)
ALTER TABLE public.machinery_logs 
ADD COLUMN IF NOT EXISTS hours_used DECIMAL(10, 2);

-- 3. Ensure work_activity exists (It should from 023, but checking)
ALTER TABLE public.machinery_logs 
ADD COLUMN IF NOT EXISTS work_activity TEXT;

-- 4. Ensure total_hours exists on MACHINERY table (not logs) for the aggregate
-- (It should from 023/034)

NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 036_fix_suppliers_project.sql
-- ============================================================
-- ============================================================
-- MIGRATION 036: FIX SUPPLIERS PROJECT ISOLATION & CONSTRAINTS
-- ============================================================

-- 1. Add project_id to suppliers table
ALTER TABLE public.suppliers 
ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE;

-- 2. Add Unique Constraint to material_grades (Material + Grade Name)
ALTER TABLE public.material_grades
ADD CONSTRAINT uq_material_grade UNIQUE (material_id, grade_name);

-- 3. Update RLS Policies for Suppliers
-- First, drop existing policies that might conflict or be too broad
DROP POLICY IF EXISTS "Admins can manage suppliers" ON public.suppliers;
DROP POLICY IF EXISTS "Site managers can view suppliers" ON public.suppliers;
DROP POLICY IF EXISTS "Site managers can add suppliers" ON public.suppliers;

-- Re-create policies with strict project isolation
CREATE POLICY "Admins can manage suppliers"
ON public.suppliers FOR ALL
TO authenticated
USING (public.is_admin_or_super());

CREATE POLICY "Site managers can view project suppliers"
ON public.suppliers FOR SELECT
TO authenticated
USING (
    public.is_assigned_to_project(project_id)
    AND is_active = true
);

CREATE POLICY "Site managers can add project suppliers"
ON public.suppliers FOR INSERT
TO authenticated
WITH CHECK (
    public.is_assigned_to_project(project_id)
);

CREATE POLICY "Site managers can update project suppliers"
ON public.suppliers FOR UPDATE
TO authenticated
USING (public.is_assigned_to_project(project_id));

-- 4. Create Helper View for Material Dropdown (Optional but requested)
CREATE OR REPLACE VIEW public.v_project_material_dropdown AS
SELECT 
    s.id, 
    s.project_id, 
    s.name, 
    s.grade, 
    s.unit,
    s.quantity -- Current tracked quantity
FROM public.stock_items s
ORDER BY s.name;

GRANT SELECT ON public.v_project_material_dropdown TO authenticated;

-- 5. Create Helper View for Project Suppliers (Optional)
CREATE OR REPLACE VIEW public.v_project_suppliers_dropdown AS
SELECT
    id,
    project_id,
    name,
    category
FROM public.suppliers
WHERE is_active = true
ORDER BY name;

GRANT SELECT ON public.v_project_suppliers_dropdown TO authenticated;

-- Notify schema reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 037_material_receipt_rpc.sql
-- ============================================================
-- ============================================================
-- MIGRATION 037: MATERIAL UNIIQUENESS & TRANSACTIONAL RECEIPT
-- ============================================================

-- 1. CLEANUP DUPLICATES IN STOCK_ITEMS
-- Before adding unique constraint, we must merge duplicate rows.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT project_id, name, grade, COUNT(*) as cnt
        FROM public.stock_items
        GROUP BY project_id, name, grade
        HAVING COUNT(*) > 1
    LOOP
        -- Merge logic: Keep the one with most recent update or creation, sum quantities onto it
        WITH duplicates AS (
            SELECT id, quantity
            FROM public.stock_items
            WHERE project_id = r.project_id 
              AND name = r.name 
              AND (grade IS NOT DISTINCT FROM r.grade)
            ORDER BY created_at DESC
        ),
        kept_row AS (
            SELECT id FROM duplicates LIMIT 1
        ),
        total_qty AS (
            SELECT SUM(quantity) as total FROM duplicates
        )
        -- Update key row
        UPDATE public.stock_items
        SET quantity = (SELECT total FROM total_qty)
        WHERE id = (SELECT id FROM kept_row);

        -- Delete others
        DELETE FROM public.stock_items
        WHERE project_id = r.project_id 
          AND name = r.name 
          AND (grade IS NOT DISTINCT FROM r.grade)
          AND id != (SELECT id FROM duplicates LIMIT 1);
          
    END LOOP;
END $$;

-- 2. ADD UNIQUE CONSTRAINT
ALTER TABLE public.stock_items
ADD CONSTRAINT uq_stock_item_project_name_grade 
UNIQUE NULLS NOT DISTINCT (project_id, name, grade);

-- 3. CREATE VENDOR_MATERIALS TABLE (For memory/suggestions)
CREATE TABLE IF NOT EXISTS public.vendor_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES public.suppliers(id) ON DELETE CASCADE,
    material_name TEXT NOT NULL,
    grade TEXT,
    last_price NUMERIC,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE NULLS NOT DISTINCT (project_id, supplier_id, material_name, grade)
);

-- Enable RLS
ALTER TABLE public.vendor_materials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view vendor materials"
ON public.vendor_materials FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can modify vendor materials"
ON public.vendor_materials FOR ALL TO authenticated USING (true);


-- 4. RPC: RECEIVE_MATERIAL (The "One RPC to Rule Them All")
CREATE OR REPLACE FUNCTION public.receive_material(
    p_project_id UUID,
    p_material_name TEXT,
    p_grade TEXT,
    p_unit TEXT,
    p_quantity NUMERIC,
    p_supplier_id UUID,
    p_bill_amount NUMERIC,
    p_payment_type TEXT DEFAULT 'Cash',
    p_activity TEXT DEFAULT 'Material Received',
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_stock_item_id UUID;
    v_log_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    -- A. UPSERT STOCK ITEM
    INSERT INTO public.stock_items (
        project_id, 
        name, 
        grade, 
        unit, 
        quantity, 
        created_by
    )
    VALUES (
        p_project_id,
        p_material_name,
        p_grade, -- Can be NULL
        p_unit,
        p_quantity,
        v_user_id
    )
    ON CONFLICT (project_id, name, grade)
    DO UPDATE SET
        quantity = public.stock_items.quantity + EXCLUDED.quantity,
        -- Update unit if it changed? Maybe keep existing. Let's keep existing to avoid overwrite confusion, 
        -- or update it to latest. Let's update unit to latest.
        unit = EXCLUDED.unit;

    -- Get the ID (whether inserted or updated)
    SELECT id INTO v_stock_item_id
    FROM public.stock_items
    WHERE project_id = p_project_id 
      AND name = p_material_name 
      AND (grade IS NOT DISTINCT FROM p_grade);

    -- B. INSERT MATERIAL LOG (History)
    INSERT INTO public.material_logs (
        project_id,
        item_id,
        log_type,
        quantity,
        activity,
        notes,
        logged_by,
        supplier_id,
        payment_type,
        bill_amount,
        grade,
        logged_at
    )
    VALUES (
        p_project_id,
        v_stock_item_id,
        'inward',
        p_quantity,
        p_activity,
        p_notes,
        v_user_id,
        p_supplier_id,
        p_payment_type,
        p_bill_amount,
        p_grade,
        NOW()
    )
    RETURNING id INTO v_log_id;

    -- C. UPSERT VENDOR_MATERIALS (Learn preference)
    INSERT INTO public.vendor_materials (
        project_id,
        supplier_id,
        material_name,
        grade,
        last_used_at
    )
    VALUES (
        p_project_id,
        p_supplier_id,
        p_material_name,
        p_grade,
        NOW()
    )
    ON CONFLICT (project_id, supplier_id, material_name, grade)
    DO UPDATE SET
        last_used_at = NOW();

    -- D. SYNC TO MASTER (Already handled by trigger on stock_items INSERT, 
    -- but if it was an UPDATE, the trigger might not fire for master table inserts if name existed. 
    -- The trigger `trigger_sync_material_master` is AFTER INSERT on stock_items.
    -- If we did an UPDATE on stock_items, we might miss adding to master if it wasn't there? 
    -- Actually stock item existence implies master existence usually. 
    -- But just in case, we can rely on the trigger for new items. 
    -- Existing items are fine.)

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify schema reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 038_fix_stock_duplicates_fk.sql
-- ============================================================
-- ============================================================
-- MIGRATION 038: ROBUST DUPLICATE CLEANUP & CONSTRAINT FIX
-- ============================================================

-- 1. CLEANUP DUPLICATES WITH FOREIGN KEY HANDLING
DO $$
DECLARE
    r RECORD;
    winner_id UUID;
    loser_id UUID;
    total_q NUMERIC;
BEGIN
    FOR r IN 
        SELECT project_id, name, grade, COUNT(*) as cnt
        FROM public.stock_items
        GROUP BY project_id, name, grade
        HAVING COUNT(*) > 1
    LOOP
        SELECT id INTO winner_id
        FROM public.stock_items
        WHERE project_id = r.project_id 
          AND name = r.name 
          AND (grade IS NOT DISTINCT FROM r.grade)
        ORDER BY created_at DESC
        LIMIT 1;

        SELECT SUM(quantity) INTO total_q
        FROM public.stock_items
        WHERE project_id = r.project_id 
          AND name = r.name 
          AND (grade IS NOT DISTINCT FROM r.grade);

        UPDATE public.stock_items
        SET quantity = total_q
        WHERE id = winner_id;

        FOR loser_id IN
            SELECT id
            FROM public.stock_items
            WHERE project_id = r.project_id 
              AND name = r.name 
              AND (grade IS NOT DISTINCT FROM r.grade)
              AND id != winner_id
        LOOP
            UPDATE public.material_logs
            SET item_id = winner_id
            WHERE item_id = loser_id;

            DELETE FROM public.stock_items WHERE id = loser_id;
        END LOOP;
    END LOOP;
END $$;

-- 2. ADD UNIQUE CONSTRAINT TO STOCK ITEMS (Explicit Name)
ALTER TABLE public.stock_items 
DROP CONSTRAINT IF EXISTS uq_stock_item_grade_project_name;

ALTER TABLE public.stock_items
ADD CONSTRAINT uq_stock_item_grade_project_name 
UNIQUE NULLS NOT DISTINCT (project_id, name, grade);


-- 3. RECREATE VENDOR_MATERIALS (With Explicit Constraint Name)
DROP TABLE IF EXISTS public.vendor_materials CASCADE;

CREATE TABLE public.vendor_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES public.suppliers(id) ON DELETE CASCADE,
    material_name TEXT NOT NULL,
    grade TEXT,
    last_price NUMERIC,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    -- Explicit constraint name for RPC usage
    CONSTRAINT uq_vendor_materials_unique 
    UNIQUE NULLS NOT DISTINCT (project_id, supplier_id, material_name, grade)
);

ALTER TABLE public.vendor_materials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view vendor materials"
ON public.vendor_materials FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can modify vendor materials"
ON public.vendor_materials FOR ALL TO authenticated USING (true);


-- 4. RPC: FIXED ON CONFLICT CLAUSES
CREATE OR REPLACE FUNCTION public.receive_material(
    p_project_id UUID,
    p_material_name TEXT,
    p_grade TEXT,
    p_unit TEXT,
    p_quantity NUMERIC,
    p_supplier_id UUID,
    p_bill_amount NUMERIC,
    p_payment_type TEXT DEFAULT 'Cash',
    p_activity TEXT DEFAULT 'Material Received',
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_stock_item_id UUID;
    v_log_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    -- A. UPSERT STOCK ITEM
    INSERT INTO public.stock_items (
        project_id, 
        name, 
        grade, 
        unit, 
        quantity, 
        created_by
    )
    VALUES (
        p_project_id,
        p_material_name,
        p_grade, 
        p_unit,
        p_quantity,
        v_user_id
    )
    ON CONFLICT ON CONSTRAINT uq_stock_item_grade_project_name
    DO UPDATE SET
        quantity = public.stock_items.quantity + EXCLUDED.quantity,
        unit = EXCLUDED.unit;

    SELECT id INTO v_stock_item_id
    FROM public.stock_items
    WHERE project_id = p_project_id 
      AND name = p_material_name 
      AND (grade IS NOT DISTINCT FROM p_grade);

    -- B. INSERT LOG
    INSERT INTO public.material_logs (
        project_id,
        item_id,
        log_type,
        quantity,
        activity,
        notes,
        logged_by,
        supplier_id,
        payment_type,
        bill_amount,
        grade,
        logged_at
    )
    VALUES (
        p_project_id,
        v_stock_item_id,
        'inward',
        p_quantity,
        p_activity,
        p_notes,
        v_user_id,
        p_supplier_id,
        p_payment_type,
        p_bill_amount,
        p_grade,
        NOW()
    )
    RETURNING id INTO v_log_id;

    -- C. UPSERT VENDOR_MATERIALS (Use Named Constraint)
    INSERT INTO public.vendor_materials (
        project_id,
        supplier_id,
        material_name,
        grade,
        last_used_at
    )
    VALUES (
        p_project_id,
        p_supplier_id,
        p_material_name,
        p_grade,
        NOW()
    )
    ON CONFLICT ON CONSTRAINT uq_vendor_materials_unique
    DO UPDATE SET
        last_used_at = NOW();

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 039_fix_payment_type_constraint.sql
-- ============================================================
-- ============================================================
-- MIGRATION 039: FIX PAYMENT TYPE CONSTRAINT
-- ============================================================

-- The previous constraint missed 'Credit', which is used in the UI.
-- We drop and recreate the constraint with the correct values.

ALTER TABLE public.material_logs 
DROP CONSTRAINT IF EXISTS material_logs_payment_type_check;

ALTER TABLE public.material_logs 
ADD CONSTRAINT material_logs_payment_type_check 
CHECK (payment_type IN (
    'Cash', 
    'Online', 
    'Cheque', 
    'Credit',       -- Added
    'UPI', 
    'Bank Transfer',
    'cash', 
    'online', 
    'cheque', 
    'credit'        -- Added lowercase just in case
));

-- Notify schema reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 040_normalize_grades.sql
-- ============================================================
-- ============================================================
-- MIGRATION 040: NORMALIZE GRADES & CLEANUP
-- ============================================================

-- 1. CLEANUP DUPLICATES IN MATERIAL_GRADES
-- Before enforcing strict uniqueness, we remove existing duplicates.
-- We normalize by lowercasing and removing spaces for comparison.
WITH normalized_counts AS (
    SELECT 
        id,
        material_id, 
        lower(regexp_replace(trim(grade_name), '\s+', '', 'g')) as norm_key,
        created_at
    FROM public.material_grades
),
duplicates AS (
    SELECT 
        id,
        row_number() OVER (PARTITION BY material_id, norm_key ORDER BY created_at DESC) as rn
    FROM normalized_counts
)
DELETE FROM public.material_grades
WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- 2. ADD GENERATED COLUMN (grade_key)
ALTER TABLE public.material_grades
ADD COLUMN IF NOT EXISTS grade_key text
GENERATED ALWAYS AS (lower(regexp_replace(trim(grade_name), '\s+', '', 'g'))) STORED;

-- 3. ENFORCE UNIQUENESS ON NORMALIZED KEY
ALTER TABLE public.material_grades
DROP CONSTRAINT IF EXISTS uq_material_grade_key;

ALTER TABLE public.material_grades
ADD CONSTRAINT uq_material_grade_key UNIQUE (material_id, grade_key);

-- 4. CLEANUP STOCK ITEMS TRIGGERS (If any exist setting name_key/grade_key)
-- We attempt to drop the likely culprit if it exists from older schema versions
DROP TRIGGER IF EXISTS trigger_set_stock_item_keys ON public.stock_items;
-- Function might be named differently, so we just ensure no bad columns exist?
-- Actually user said "Drop anything that assigns NEW.name_key".
-- We can't dynamic SQL drop easily without knowing name. 
-- But we can ensure the COLUMNS themselves don't exist if they were legacy.
-- If columns exist, we drop them.
ALTER TABLE public.stock_items DROP COLUMN IF EXISTS name_key;
ALTER TABLE public.stock_items DROP COLUMN IF EXISTS grade_key;

-- Notify schema reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 041_fix_material_addition.sql
-- ============================================================
-- ============================================================
-- Migration 041: Fix Material Addition Issues
-- ============================================================
-- Date: 2026-02-06
-- Description: Fixes material addition failures by:
--   1. Replacing receive_material RPC with atomic UPSERT
--   2. Fixing update_vendor_materials trigger constraint
--   3. Allowing NULL grades in stock_items
-- ============================================================

-- 1. Allow NULL grades (materials like Sand don't have grades)
ALTER TABLE public.stock_items
  ALTER COLUMN grade DROP NOT NULL;

-- 2. Replace receive_material RPC with improved UPSERT version
DROP FUNCTION IF EXISTS public.receive_material;

CREATE OR REPLACE FUNCTION public.receive_material(
    p_project_id UUID,
    p_material_name TEXT,
    p_grade TEXT,
    p_unit TEXT,
    p_quantity NUMERIC,
    p_supplier_id UUID,
    p_bill_amount NUMERIC,
    p_payment_type TEXT DEFAULT 'Cash',
    p_activity TEXT DEFAULT 'Material Received',
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp  -- Security fix: prevent search_path attacks
AS $$
DECLARE
    v_stock_item_id UUID;
    v_log_id UUID;
    v_user_id UUID := auth.uid();
    v_grade TEXT := NULLIF(TRIM(p_grade), '');  -- Convert empty string to NULL
BEGIN
    -- 1) UPSERT stock item (Atomic: prevents race conditions)
    INSERT INTO public.stock_items (project_id, name, grade, unit, quantity, created_by)
    VALUES (p_project_id, TRIM(p_material_name), v_grade, p_unit, p_quantity, v_user_id)
    ON CONFLICT ON CONSTRAINT uq_stock_item_grade_project_name
    DO UPDATE SET
        quantity = public.stock_items.quantity + EXCLUDED.quantity,
        unit = EXCLUDED.unit;

    -- Get the stock item ID
    SELECT id INTO v_stock_item_id
    FROM public.stock_items
    WHERE project_id = p_project_id
      AND name = TRIM(p_material_name)
      AND (grade IS NOT DISTINCT FROM v_grade);

    -- 2) Insert material log (audit trail)
    INSERT INTO public.material_logs (
        project_id, item_id, log_type, quantity, activity, notes,
        logged_by, supplier_id, payment_type, bill_amount, grade, logged_at
    )
    VALUES (
        p_project_id, v_stock_item_id, 'inward', p_quantity, p_activity, p_notes,
        v_user_id, p_supplier_id, p_payment_type, p_bill_amount, v_grade, NOW()
    )
    RETURNING id INTO v_log_id;

    -- 3) Update vendor materials (for dropdown suggestions)
    INSERT INTO public.vendor_materials (project_id, supplier_id, material_name, grade, last_used_at)
    VALUES (p_project_id, p_supplier_id, TRIM(p_material_name), v_grade, NOW())
    ON CONFLICT ON CONSTRAINT uq_vendor_materials_unique
    DO UPDATE SET last_used_at = NOW();

    RETURN v_log_id;
END;
$$;

-- 3. Fix update_vendor_materials trigger to include project_id
CREATE OR REPLACE FUNCTION public.update_vendor_materials()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.log_type = 'inward' AND NEW.supplier_id IS NOT NULL THEN
    -- FIXED: Include project_id in the UPSERT
    INSERT INTO public.vendor_materials (project_id, supplier_id, material_name, grade, last_price, last_used_at)
    SELECT 
      NEW.project_id,  -- ADDED: project_id
      NEW.supplier_id,
      s.name,
      COALESCE(NEW.grade, s.grade),
      NEW.bill_amount / NULLIF(NEW.quantity, 0),
      NOW()
    FROM public.stock_items s WHERE s.id = NEW.item_id
    ON CONFLICT ON CONSTRAINT uq_vendor_materials_unique  -- Use constraint name
    DO UPDATE SET 
      last_price = EXCLUDED.last_price,
      last_used_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- VERIFICATION QUERIES (Run these to validate)
-- ============================================================
-- Check function exists with correct signature:
-- SELECT proname, prosecdef, pg_get_function_identity_arguments(oid)
-- FROM pg_proc WHERE proname = 'receive_material';

-- Check grade column allows NULL:
-- SELECT column_name, is_nullable FROM information_schema.columns
-- WHERE table_name = 'stock_items' AND column_name = 'grade';

-- Test material addition:
-- SELECT receive_material(
--   p_project_id := 'your-project-id'::uuid,
--   p_material_name := 'Test Material',
--   p_grade := 'Grade A',
--   p_unit := 'Kg',
--   p_quantity := 100,
--   p_supplier_id := 'your-supplier-id'::uuid,
--   p_bill_amount := 5000
-- );
-- ============================================================


-- ============================================================
-- 042_fix_material_grades_upsert.sql
-- ============================================================
-- ============================================================
-- Migration 042: Fix Material Grades Duplicate Key Error
-- ============================================================
-- Date: 2026-02-06
-- Description: Fixes duplicate key error in material_grades when
--   adding materials with different grade name formats (e.g., "18 MM" vs "18MM")
--   that normalize to the same grade_key
-- ============================================================

-- Problem:
-- The sync_material_master() function used ON CONFLICT (material_id, grade_name)
-- but the unique constraint that matters is uq_material_grade_key on (material_id, grade_key).
-- Since grade_key is GENERATED ALWAYS AS (lower(regexp_replace(trim(grade_name), '\s+', '', 'g'))),
-- both "18MM" and "18 MM" normalize to "18mm", causing duplicate key violations.

-- Solution:
-- Update the function to use ON CONFLICT ON CONSTRAINT uq_material_grade_key

CREATE OR REPLACE FUNCTION public.sync_material_master()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_material_id UUID;
BEGIN
  -- 1. Sync Material Name
  INSERT INTO public.material_master (name)
  VALUES (NEW.name)
  ON CONFLICT (name) DO NOTHING;
  
  SELECT id INTO v_material_id FROM public.material_master WHERE name = NEW.name;

  -- 2. Sync Grade if present
  IF NEW.grade IS NOT NULL THEN
    -- FIXED: Use uq_material_grade_key constraint instead of (material_id, grade_name)
    -- This prevents duplicates when "18MM" and "18 MM" both normalize to grade_key "18mm"
    INSERT INTO public.material_grades (material_id, grade_name)
    VALUES (v_material_id, NEW.grade)
    ON CONFLICT ON CONSTRAINT uq_material_grade_key DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- VERIFICATION
-- ============================================================
-- Test adding same material with different grade formats:
-- Both should succeed and reference the same material_grades entry

-- SELECT receive_material(
--   p_project_id := 'your-project-id'::uuid,
--   p_material_name := 'Steel',
--   p_grade := '18 MM',  -- With space
--   p_unit := 'Ton',
--   p_quantity := 10,
--   p_supplier_id := 'supplier-id'::uuid,
--   p_bill_amount := 100000
-- );

-- SELECT receive_material(
--   p_project_id := 'your-project-id'::uuid,
--   p_material_name := 'Steel',
--   p_grade := '18MM',  -- Without space
--   p_unit := 'Ton',
--   p_quantity := 10,
--   p_supplier_id := 'supplier-id'::uuid,
--   p_bill_amount := 100000
-- );

-- Verify only one material_grades entry exists:
-- SELECT grade_name, grade_key FROM material_grades
-- WHERE material_id = (SELECT id FROM material_master WHERE name = 'Steel')
--   AND grade_key = '18mm';
-- ============================================================


-- ============================================================
-- 043_get_material_breakdown_rpc.sql
-- ============================================================
-- Create RPC function to get material breakdown (Received, Consumed, Remaining)
-- This aggregates data from stock_items and material_logs

DROP FUNCTION IF EXISTS get_project_material_breakdown(UUID);

CREATE OR REPLACE FUNCTION get_project_material_breakdown(p_project_id UUID)
RETURNS TABLE (
    name TEXT,
    received NUMERIC,
    consumed NUMERIC,
    remaining NUMERIC,
    unit TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH stock_aggregates AS (
        -- Get all stock items for the project
        SELECT 
            s.id,
            s.name,
            s.unit,
            s.quantity as current_quantity
        FROM stock_items s
        WHERE s.project_id = p_project_id
    ),
    log_aggregates AS (
        -- Aggregate logs by item_id
        SELECT 
            ml.item_id,
            COALESCE(SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END), 0) as received,
            COALESCE(SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END), 0) as consumed
        FROM material_logs ml
        WHERE ml.project_id = p_project_id
        GROUP BY ml.item_id
    )
    SELECT 
        sa.name,
        -- Sum up stats for all items sharing the same name (e.g. diff grades of Steel)
        SUM(COALESCE(la.received, 0)) as received,
        SUM(COALESCE(la.consumed, 0)) as consumed,
        SUM(sa.current_quantity) as remaining,
        sa.unit
    FROM stock_aggregates sa
    LEFT JOIN log_aggregates la ON sa.id = la.item_id
    GROUP BY sa.name, sa.unit
    ORDER BY sa.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_project_material_breakdown(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_project_material_breakdown(UUID) TO service_role;


-- ============================================================
-- 044_fix_stock_logic.sql
-- ============================================================
-- ============================================================
-- Migration 044: Fix Stock Logic (Auto-update on Logs)
-- ============================================================

-- 1. Create Trigger Function to update stock based on logs
CREATE OR REPLACE FUNCTION public.update_stock_from_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.log_type = 'inward' THEN
        -- Increase stock
        UPDATE public.stock_items
        SET quantity = quantity + NEW.quantity,
            updated_at = NOW()
        WHERE id = NEW.item_id;
    ELSIF NEW.log_type = 'outward' THEN
        -- Decrease stock
        UPDATE public.stock_items
        SET quantity = quantity - NEW.quantity,
            updated_at = NOW()
        WHERE id = NEW.item_id;
    END IF;
    RETURN NEW;
END;
$$;

-- 2. Create Trigger on material_logs
DROP TRIGGER IF EXISTS trigger_update_stock_on_log ON public.material_logs;
CREATE TRIGGER trigger_update_stock_on_log
    AFTER INSERT ON public.material_logs
    FOR EACH ROW
    EXECUTE FUNCTION public.update_stock_from_log();


-- 3. Update receive_material RPC to remove manual stock update (Prevent Double Counting)
-- Logic change: We now insert/ensure the item exists with 0 quantity (or ignore if exists),
-- and let the subsequent INSERT into material_logs trigger the actual quantity update.

DROP FUNCTION IF EXISTS public.receive_material;

CREATE OR REPLACE FUNCTION public.receive_material(
    p_project_id UUID,
    p_material_name TEXT,
    p_grade TEXT,
    p_unit TEXT,
    p_quantity NUMERIC,
    p_supplier_id UUID,
    p_bill_amount NUMERIC,
    p_payment_type TEXT DEFAULT 'Cash',
    p_activity TEXT DEFAULT 'Material Received',
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_stock_item_id UUID;
    v_log_id UUID;
    v_user_id UUID := auth.uid();
    v_grade TEXT := NULLIF(TRIM(p_grade), '');
BEGIN
    -- 1) Ensure Stock Item Exists (Idempotent)
    -- We insert with 0 quantity if new. If exists, we DO NOTHING (preserve current qty).
    -- The trigger on material_logs will handle the addition.
    INSERT INTO public.stock_items (project_id, name, grade, unit, quantity, created_by)
    VALUES (p_project_id, TRIM(p_material_name), v_grade, p_unit, 0, v_user_id)
    ON CONFLICT ON CONSTRAINT uq_stock_item_grade_project_name
    DO UPDATE SET unit = EXCLUDED.unit; -- Optional: update unit if changed, but don't touch quantity

    -- Get the stock item ID
    SELECT id INTO v_stock_item_id
    FROM public.stock_items
    WHERE project_id = p_project_id
      AND name = TRIM(p_material_name)
      AND (grade IS NOT DISTINCT FROM v_grade);

    -- 2) Insert material log (THIS FIRES THE TRIGGER to update stock)
    INSERT INTO public.material_logs (
        project_id, item_id, log_type, quantity, activity, notes,
        logged_by, supplier_id, payment_type, bill_amount, grade, logged_at
    )
    VALUES (
        p_project_id, v_stock_item_id, 'inward', p_quantity, p_activity, p_notes,
        v_user_id, p_supplier_id, p_payment_type, p_bill_amount, v_grade, NOW()
    )
    RETURNING id INTO v_log_id;

    -- 3) Update vendor materials (unchanged)
    INSERT INTO public.vendor_materials (project_id, supplier_id, material_name, grade, last_used_at)
    VALUES (p_project_id, p_supplier_id, TRIM(p_material_name), v_grade, NOW())
    ON CONFLICT ON CONSTRAINT uq_vendor_materials_unique
    DO UPDATE SET last_used_at = NOW();

    -- Also update price tracking since we have bill amount
    IF p_quantity > 0 THEN
      UPDATE public.vendor_materials
      SET last_price = p_bill_amount / p_quantity
      WHERE project_id = p_project_id
        AND supplier_id = p_supplier_id
        AND material_name = TRIM(p_material_name)
        AND (grade IS NOT DISTINCT FROM v_grade);
    END IF;

    RETURN v_log_id;
END;
$$;


-- ============================================================
-- 045_fix_material_quantity_sync.sql
-- ============================================================
-- ============================================================
-- Migration 045: Fix Material Quantity Sync Issues
-- ============================================================
-- Date: 2026-02-07
-- Description: Reconciles stock_items.quantity with material_logs
--   to fix mismatches where outward logs didn't update stock.
-- ============================================================

-- PART 1: DATA RECONCILIATION
-- ============================================================

-- Step 1: Recalculate all stock quantities from material_logs
-- This is the source of truth for actual inventory
UPDATE stock_items si
SET quantity = (
  SELECT COALESCE(SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END), 0)
  FROM material_logs ml
  WHERE ml.item_id = si.id
)
WHERE EXISTS (SELECT 1 FROM material_logs WHERE item_id = si.id);

-- Step 2: Delete orphaned stock items (no logs and zero quantity)
DELETE FROM stock_items
WHERE quantity = 0
  AND NOT EXISTS (SELECT 1 FROM material_logs WHERE item_id = stock_items.id);

-- Step 3: Add validation constraint to prevent negative stock
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'chk_stock_quantity_non_negative'
  ) THEN
    ALTER TABLE stock_items
    ADD CONSTRAINT chk_stock_quantity_non_negative
    CHECK (quantity >= 0);
  END IF;
END $$;

-- ============================================================
-- PART 2: FIX get_project_material_breakdown RPC
-- ============================================================

-- Drop and recreate with corrected logic
DROP FUNCTION IF EXISTS get_project_material_breakdown(UUID);

CREATE OR REPLACE FUNCTION get_project_material_breakdown(p_project_id UUID)
RETURNS TABLE (
    name TEXT,
    received NUMERIC,
    consumed NUMERIC,
    remaining NUMERIC,
    unit TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH stock_aggregates AS (
        -- Get all stock items for the project
        SELECT 
            s.id,
            s.name,
            s.unit
        FROM stock_items s
        WHERE s.project_id = p_project_id
    ),
    log_aggregates AS (
        -- Aggregate logs by item_id
        SELECT 
            ml.item_id,
            COALESCE(SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END), 0) as received,
            COALESCE(SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END), 0) as consumed
        FROM material_logs ml
        WHERE ml.project_id = p_project_id
        GROUP BY ml.item_id
    )
    SELECT 
        sa.name,
        -- Sum up stats for all items sharing the same name (e.g. diff grades of Steel)
        SUM(COALESCE(la.received, 0)) as received,
        SUM(COALESCE(la.consumed, 0)) as consumed,
        -- FIXED: Calculate remaining from logs (source of truth)
        SUM(COALESCE(la.received, 0)) - SUM(COALESCE(la.consumed, 0)) as remaining,
        sa.unit
    FROM stock_aggregates sa
    LEFT JOIN log_aggregates la ON sa.id = la.item_id
    GROUP BY sa.name, sa.unit
    ORDER BY sa.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_project_material_breakdown(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_project_material_breakdown(UUID) TO service_role;

-- ============================================================
-- PART 3: VERIFICATION QUERIES
-- ============================================================

-- Query 1: Check for any remaining mismatches
DO $$
DECLARE
  v_mismatch_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_mismatch_count
  FROM stock_items si
  LEFT JOIN (
    SELECT item_id,
      COALESCE(SUM(CASE WHEN log_type = 'inward' THEN quantity ELSE 0 END), 0) -
      COALESCE(SUM(CASE WHEN log_type = 'outward' THEN quantity ELSE 0 END), 0) as calc_qty
    FROM material_logs
    GROUP BY item_id
  ) ml ON si.id = ml.item_id
  WHERE si.quantity != COALESCE(ml.calc_qty, 0);
  
  RAISE NOTICE 'Mismatches remaining: %', v_mismatch_count;
  
  IF v_mismatch_count > 0 THEN
    RAISE WARNING 'Still have % mismatches after reconciliation!', v_mismatch_count;
  ELSE
    RAISE NOTICE 'SUCCESS: All stock quantities are now in sync with logs!';
  END IF;
END $$;

-- Query 2: Check for orphaned stock items
DO $$
DECLARE
  v_orphaned_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_orphaned_count
  FROM stock_items
  WHERE quantity = 0
    AND NOT EXISTS (SELECT 1 FROM material_logs WHERE item_id = stock_items.id);
  
  RAISE NOTICE 'Orphaned stock items: %', v_orphaned_count;
  
  IF v_orphaned_count > 0 THEN
    RAISE WARNING 'Still have % orphaned stock items!', v_orphaned_count;
  END IF;
END $$;

-- Query 3: Display reconciliation summary
DO $$
DECLARE
  v_record RECORD;
BEGIN
  RAISE NOTICE '=== RECONCILIATION SUMMARY ===';
  
  FOR v_record IN
    SELECT 
      name,
      grade,
      unit,
      quantity as current_stock,
      (SELECT SUM(CASE WHEN log_type = 'inward' THEN quantity ELSE 0 END) -
              SUM(CASE WHEN log_type = 'outward' THEN quantity ELSE 0 END)
       FROM material_logs WHERE item_id = stock_items.id) as calculated_stock
    FROM stock_items
    WHERE (name ILIKE '%steel%' OR name ILIKE '%cement%')
    ORDER BY name, grade
  LOOP
    RAISE NOTICE '% (%) [%]: Stock=%, Calculated=%', 
      v_record.name, 
      COALESCE(v_record.grade, 'NULL'), 
      v_record.unit,
      v_record.current_stock,
      v_record.calculated_stock;
  END LOOP;
END $$;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================


-- ============================================================
-- 046_fix_machinery_logs_reading_columns.sql
-- ============================================================
-- Migration 046: Fix Machinery Logs Schema
-- Ensures reading columns exist and refreshes schema cache

-- Ensure start_reading and end_reading exist
ALTER TABLE public.machinery_logs 
ADD COLUMN IF NOT EXISTS start_reading DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS end_reading DECIMAL(10, 2);

-- Ensure execution_hours exists (calculated field)
ALTER TABLE public.machinery_logs 
ADD COLUMN IF NOT EXISTS execution_hours DECIMAL(10, 2);

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 047_add_bill_operation_logs.sql
-- ============================================================
-- Extend operation_logs entity_type to support bills and notifications
ALTER TABLE public.operation_logs
  DROP CONSTRAINT IF EXISTS operation_logs_entity_type_check;

ALTER TABLE public.operation_logs
  ADD CONSTRAINT operation_logs_entity_type_check
  CHECK (entity_type IN ('project', 'stock', 'labour', 'blueprint', 'machinery', 'attendance', 'report', 'bill'));

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- 048_add_user_details.sql
-- ============================================================
-- Add position and address columns to user_profiles table
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS "position" text,
ADD COLUMN IF NOT EXISTS address text;

-- Update the handle_new_user function to include these fields if they are passed in metadata
-- Note: The trigger function usually copies from raw_user_meta_data, so ensuring those are passed in signUp is key.
-- But we can also rely on the explicit update we do in the repository after creation.


-- ============================================================
-- 049_allow_admin_delete_users.sql
-- ============================================================
-- ============================================================
-- ALLOW ADMINS TO DELETE USER PROFILES
-- ============================================================

-- Drop the old policy that only allows super admins
DROP POLICY IF EXISTS "Super admins can delete profiles" ON public.user_profiles;
DROP POLICY IF EXISTS " Adminscan delete profiles" ON public.user_profiles;

-- Create the new policy allowing admins (and super admins) to delete profiles
CREATE POLICY "Admins can delete profiles"
    ON public.user_profiles FOR DELETE
    USING (public.is_admin_or_super());


-- ============================================================
-- 050_create_bill_on_material_receive.sql
-- ============================================================
-- ============================================================
-- Migration 050: Create Bill On Material Receive
-- ============================================================
-- Modifies the receive_material RPC to automatically create a bill
-- linked to the specific project and vendor.
-- ============================================================

CREATE OR REPLACE FUNCTION public.receive_material(
    p_project_id UUID,
    p_material_name TEXT,
    p_grade TEXT,
    p_unit TEXT,
    p_quantity NUMERIC,
    p_supplier_id UUID,
    p_bill_amount NUMERIC,
    p_payment_type TEXT DEFAULT 'Cash',
    p_activity TEXT DEFAULT 'Material Received',
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_stock_item_id UUID;
    v_log_id UUID;
    v_bill_id UUID;
    v_user_id UUID := auth.uid();
    v_grade TEXT := NULLIF(TRIM(p_grade), '');
    v_vendor_name TEXT;
    v_bill_title TEXT;
    v_bill_description TEXT;
BEGIN
    -- 0) Get Vendor Name
    SELECT name INTO v_vendor_name
    FROM public.suppliers
    WHERE id = p_supplier_id;

    -- 1) Ensure Stock Item Exists (Idempotent)
    -- We insert with 0 quantity if new. If exists, we DO NOTHING (preserve current qty).
    -- The trigger on material_logs will handle the addition.
    INSERT INTO public.stock_items (project_id, name, grade, unit, quantity, created_by)
    VALUES (p_project_id, TRIM(p_material_name), v_grade, p_unit, 0, v_user_id)
    ON CONFLICT ON CONSTRAINT uq_stock_item_grade_project_name
    DO UPDATE SET unit = EXCLUDED.unit; -- Optional: update unit if changed, but don't touch quantity

    -- Get the stock item ID
    SELECT id INTO v_stock_item_id
    FROM public.stock_items
    WHERE project_id = p_project_id
      AND name = TRIM(p_material_name)
      AND (grade IS NOT DISTINCT FROM v_grade);

    -- 2) Insert material log (THIS FIRES THE TRIGGER to update stock)
    INSERT INTO public.material_logs (
        project_id, item_id, log_type, quantity, activity, notes,
        logged_by, supplier_id, payment_type, bill_amount, grade, logged_at
    )
    VALUES (
        p_project_id, v_stock_item_id, 'inward', p_quantity, p_activity, p_notes,
        v_user_id, p_supplier_id, p_payment_type, p_bill_amount, v_grade, NOW()
    )
    RETURNING id INTO v_log_id;

    -- 3) Create associated auto-bill
    IF v_grade IS NOT NULL THEN
        v_bill_title := 'Material Receive: ' || TRIM(p_material_name) || ' (' || v_grade || ')';
    ELSE
        v_bill_title := 'Material Receive: ' || TRIM(p_material_name);
    END IF;

    v_bill_description := 'Quantity: ' || p_quantity::TEXT || ' ' || p_unit || ', Vendor: ' || v_vendor_name;
    IF p_notes IS NOT NULL THEN
        v_bill_description := v_bill_description || ', Notes: ' || p_notes;
    END IF;

    -- Map Flutter payment types to DB constraint ('cash', 'upi', 'bank_transfer', 'cheque')
    DECLARE
        v_payment_type TEXT := LOWER(p_payment_type);
    BEGIN
        IF v_payment_type = 'online' THEN
            v_payment_type := 'bank_transfer';
        ELSIF v_payment_type NOT IN ('cash', 'upi', 'bank_transfer', 'cheque') THEN
            v_payment_type := 'cash'; -- default fallback
        END IF;

        INSERT INTO public.bills (
            project_id, 
            title, 
            description, 
            amount, 
            bill_type, 
            status, 
            bill_date, 
            created_by,
            raised_by,
            uploaded_by,
            payment_type,
            payment_status
        ) VALUES (
            p_project_id,
            v_bill_title,
            v_bill_description,
            p_bill_amount,
            'materials',  -- defined in enum/check constraint
            'pending',  
            CURRENT_DATE,
            v_user_id,
            v_user_id,
            v_user_id,
            v_payment_type,
            'need_to_pay'
        ) RETURNING id INTO v_bill_id;
    END;

    -- 4) Update vendor materials (unchanged)
    INSERT INTO public.vendor_materials (project_id, supplier_id, material_name, grade, last_used_at)
    VALUES (p_project_id, p_supplier_id, TRIM(p_material_name), v_grade, NOW())
    ON CONFLICT ON CONSTRAINT uq_vendor_materials_unique
    DO UPDATE SET last_used_at = NOW();

    -- 5) Also update price tracking since we have bill amount
    IF p_quantity > 0 THEN
      UPDATE public.vendor_materials
      SET last_price = p_bill_amount / p_quantity
      WHERE project_id = p_project_id
        AND supplier_id = p_supplier_id
        AND material_name = TRIM(p_material_name)
        AND (grade IS NOT DISTINCT FROM v_grade);
    END IF;

    RETURN v_log_id;
END;
$$;


-- ============================================================
-- 050b_set_projects_active.sql
-- ============================================================
-- Migration: Set all existing 'planning' projects to 'in_progress' (active)
-- New projects will also default to 'in_progress' via the Flutter app model

UPDATE projects
SET status = 'in_progress',
    updated_at = NOW()
WHERE status = 'planning'
  AND deleted_at IS NULL;


-- ============================================================
-- 051_fix_storage_rls_security.sql
-- ============================================================
-- ============================================================
-- MIGRATION 051: Fix Storage RLS Security
-- ============================================================
-- Problem: Previous storage policies on blueprints and receipts buckets
-- allowed ANY authenticated user to view/upload objects, regardless of
-- project assignment. A site manager assigned to Project A could read
-- Project B's sensitive construction documents and receipts.
--
-- Fix: Restrict storage access to project members only.
-- Admins retain full access. Site managers can only access files
-- belonging to projects they are assigned to.
-- ============================================================

-- ============================================================
-- 1. FIX BLUEPRINTS BUCKET POLICIES
-- ============================================================

-- Drop the overly-permissive existing policies
DROP POLICY IF EXISTS "Authenticated users can view blueprints" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload blueprints" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update blueprints" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete blueprints" ON storage.objects;

-- Allow admins to access all blueprints
CREATE POLICY "Admins can manage all blueprints storage"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'blueprints'
    AND EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    bucket_id = 'blueprints'
    AND EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  );

-- Allow site managers to view blueprints for their assigned projects only
-- Blueprint storage paths are expected to be: {project_id}/{filename}
CREATE POLICY "Site managers can view project blueprints storage"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'blueprints'
    AND EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.user_id = auth.uid()
        AND (storage.foldername(name))[1] = pa.project_id::text
    )
  );

-- Allow site managers to upload blueprints for their assigned projects
CREATE POLICY "Site managers can upload project blueprints storage"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'blueprints'
    AND EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.user_id = auth.uid()
        AND (storage.foldername(name))[1] = pa.project_id::text
    )
  );

-- Allow site managers to delete their own uploads
CREATE POLICY "Site managers can delete project blueprints storage"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'blueprints'
    AND EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.user_id = auth.uid()
        AND (storage.foldername(name))[1] = pa.project_id::text
    )
  );

-- ============================================================
-- 2. FIX RECEIPTS BUCKET POLICIES
-- ============================================================

DROP POLICY IF EXISTS "Authenticated users can view receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update receipts" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete receipts" ON storage.objects;

-- Admins manage all receipts
CREATE POLICY "Admins can manage all receipts storage"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'receipts'
    AND EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    bucket_id = 'receipts'
    AND EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  );

-- Site managers can view receipts for their projects
-- Receipt storage paths expected: {project_id}/{filename}
CREATE POLICY "Site managers can view project receipts storage"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'receipts'
    AND EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.user_id = auth.uid()
        AND (storage.foldername(name))[1] = pa.project_id::text
    )
  );

-- Site managers can upload receipts for their projects
CREATE POLICY "Site managers can upload project receipts storage"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'receipts'
    AND EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.user_id = auth.uid()
        AND (storage.foldername(name))[1] = pa.project_id::text
    )
  );

-- ============================================================
-- 3. FIX BILLS BUCKET POLICIES (if bucket exists)
-- ============================================================

DROP POLICY IF EXISTS "Authenticated users can view bills" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload bills" ON storage.objects;

CREATE POLICY "Admins can manage all bills storage"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'bills'
    AND EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    bucket_id = 'bills'
    AND EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Site managers can manage project bills storage"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'bills'
    AND EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.user_id = auth.uid()
        AND (storage.foldername(name))[1] = pa.project_id::text
    )
  )
  WITH CHECK (
    bucket_id = 'bills'
    AND EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.user_id = auth.uid()
        AND (storage.foldername(name))[1] = pa.project_id::text
    )
  );

-- ============================================================
-- 4. ADD delete-user RPC FUNCTION (admin-only, service_role enforced)
-- ============================================================
-- This function deletes a user from auth.users (which cascades to user_profiles).
-- It uses SECURITY DEFINER to run with elevated privileges.
-- The caller check ensures only admins/super_admins can invoke it.

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- Verify caller is admin or super_admin
  SELECT role INTO caller_role
  FROM public.user_profiles
  WHERE id = auth.uid();

  IF caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Permission denied: only admins can delete users';
  END IF;

  -- Prevent self-deletion
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  -- Delete from auth.users (cascades to user_profiles via FK)
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;

-- Grant execute to authenticated users (the function itself enforces role check)
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated;

COMMENT ON FUNCTION public.admin_delete_user IS
  'Deletes a user from auth.users and cascades to user_profiles. Caller must be admin or super_admin.';

