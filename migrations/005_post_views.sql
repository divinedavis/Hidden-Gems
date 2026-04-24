-- ============================================================
-- Hidden Gems — post view tracking
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- One row per (viewer, post) the viewer has either dwelled on for
-- ~2s in the feed, tapped into, liked, saved, or commented on.
-- Used by the client to order the feed unseen-first and hide seen
-- posts from the main scroll until the unseen queue is exhausted.
create table if not exists post_views (
  user_id uuid references users(id) on delete cascade,
  post_id uuid references posts(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, post_id)
);

alter table post_views enable row level security;

drop policy if exists "Public read" on post_views;
create policy "Public read" on post_views
  for select using (true);

drop policy if exists "Users can manage own views" on post_views;
create policy "Users can manage own views" on post_views
  for all using (auth.uid() = user_id);
