-- 005_storage_rls.sql
-- Locks down the Supabase Storage `avatars` bucket so only the owner can
-- read or write their own avatar file.
-- Run in Supabase SQL editor or via: supabase db push
--
-- The bucket must already exist (create it via the Supabase dashboard or
-- `supabase storage create avatars`). This migration only sets the policies.

-- Ensure the bucket is private (non-public).
-- If the bucket was created as public you can change it here.
update storage.buckets
   set public = false
 where id = 'avatars';

-- Drop any previously created policies so this migration is idempotent.
drop policy if exists "avatars_owner_select"  on storage.objects;
drop policy if exists "avatars_owner_insert"  on storage.objects;
drop policy if exists "avatars_owner_update"  on storage.objects;
drop policy if exists "avatars_owner_delete"  on storage.objects;

-- SELECT: owner can read their own avatar.
create policy "avatars_owner_select" on storage.objects
  for select
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (string_to_array(name, '/'))[2]
  );

-- INSERT: owner can upload a new avatar to their own path (avatars/{uid}.*).
create policy "avatars_owner_insert" on storage.objects
  for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (string_to_array(name, '/'))[2]
  );

-- UPDATE: owner can overwrite their own avatar (upsert).
create policy "avatars_owner_update" on storage.objects
  for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (string_to_array(name, '/'))[2]
  );

-- DELETE: owner can remove their own avatar.
create policy "avatars_owner_delete" on storage.objects
  for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (string_to_array(name, '/'))[2]
  );
