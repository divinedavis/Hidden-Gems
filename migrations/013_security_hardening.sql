-- ============================================================
-- Hidden Gems — RLS hardening
--
-- Two changes:
-- 1. The "Anyone can insert restaurants" policy applied to the
--    `public` Postgres role (which covers both `anon` and
--    `authenticated`) and used `with_check: true`, so any client
--    holding the publishable key — including signed-out
--    devices — could spam restaurant rows. Tightened to require
--    authenticated session.
-- 2. Several `FOR ALL` and `FOR UPDATE` policies omitted
--    WITH CHECK and relied on Postgres's "reuse USING when
--    WITH CHECK is null" fallback. Behaviorally identical, but
--    explicit beats implicit — and a future Postgres major could
--    in theory tighten that semantics. Added explicit clauses.
-- ============================================================

-- 1. restaurants INSERT — authenticated only.
drop policy if exists "Anyone can insert restaurants" on restaurants;
create policy "Authenticated users can insert restaurants" on restaurants
  for insert to authenticated
  with check (auth.uid() is not null);

-- 2. Make ALL/UPDATE WITH CHECK explicit on per-user tables.
drop policy if exists "Users can manage comment likes" on comment_likes;
create policy "Users can manage comment likes" on comment_likes
  for all to public
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can manage follows" on follows;
create policy "Users can manage follows" on follows
  for all to public
  using (auth.uid() = follower_id)
  with check (auth.uid() = follower_id);

drop policy if exists "Users can manage likes" on likes;
create policy "Users can manage likes" on likes
  for all to public
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can manage own views" on post_views;
create policy "Users can manage own views" on post_views
  for all to public
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can manage ratings" on ratings;
create policy "Users can manage ratings" on ratings
  for all to public
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can manage saved" on saved_restaurants;
create policy "Users can manage saved" on saved_restaurants
  for all to public
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 3. users UPDATE — explicit WITH CHECK so a user can't update
--    their row to claim a different id (USING reuse already
--    blocks this in current Postgres, but make it ironclad).
drop policy if exists "Users can update own profile" on users;
create policy "Users can update own profile" on users
  for update to public
  using (auth.uid() = id)
  with check (auth.uid() = id);
