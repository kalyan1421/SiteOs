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
