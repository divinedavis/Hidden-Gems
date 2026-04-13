-- ============================================================
-- Hidden Gems — security hardening
-- Run this ONCE in the Supabase SQL Editor.
-- ============================================================
-- Fixes the Critical finding from the security audit:
-- restaurants had `insert with check (true)` and no UPDATE or
-- DELETE policies, meaning anyone could spam restaurants and
-- nobody (even the creator) could edit or remove them.

-- Track who created each restaurant.
alter table restaurants
  add column if not exists creator_id uuid references users(id);

-- Replace the permissive insert policy with one scoped to the
-- authenticated session user.
drop policy if exists "Anyone can insert restaurants" on restaurants;

create policy "Authenticated users can insert restaurants"
  on restaurants for insert
  to authenticated
  with check (auth.uid() = creator_id);

-- Creators own update and delete on their rows. Legacy rows
-- (creator_id = null) stay locked until an admin backfills them
-- via the service role.
create policy "Creators can update their restaurants"
  on restaurants for update
  to authenticated
  using (auth.uid() = creator_id);

create policy "Creators can delete their restaurants"
  on restaurants for delete
  to authenticated
  using (auth.uid() = creator_id);
