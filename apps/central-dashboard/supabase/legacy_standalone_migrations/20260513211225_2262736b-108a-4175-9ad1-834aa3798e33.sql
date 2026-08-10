-- 1) Explicit admin-only mutations on user_roles (prevent self-escalation)
DROP POLICY IF EXISTS "Only admins can insert roles" ON public.user_roles;
CREATE POLICY "Only admins can insert roles"
ON public.user_roles
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Only admins can update roles" ON public.user_roles;
CREATE POLICY "Only admins can update roles"
ON public.user_roles
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Only admins can delete roles" ON public.user_roles;
CREATE POLICY "Only admins can delete roles"
ON public.user_roles
FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- 2) Restrict admin/moderator invitations to admins only
DROP POLICY IF EXISTS "Authenticated can create invitations" ON public.invitations;
CREATE POLICY "Authenticated can create invitations"
ON public.invitations
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = invited_by
  AND (
    role = 'user'::public.app_role
    OR public.has_role(auth.uid(), 'admin')
  )
);

-- 3) Enforce folder ownership on bug-attachments INSERT and add UPDATE policy
DROP POLICY IF EXISTS "Authenticated can upload bug attachments" ON storage.objects;
CREATE POLICY "Authenticated can upload bug attachments"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'bug-attachments'
  AND (storage.foldername(name))[1] = (auth.uid())::text
);

DROP POLICY IF EXISTS "Users can update own bug attachments" ON storage.objects;
CREATE POLICY "Users can update own bug attachments"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'bug-attachments'
  AND (storage.foldername(name))[1] = (auth.uid())::text
)
WITH CHECK (
  bucket_id = 'bug-attachments'
  AND (storage.foldername(name))[1] = (auth.uid())::text
);
