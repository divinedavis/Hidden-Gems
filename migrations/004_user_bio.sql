-- ============================================================
-- Hidden Gems — user bio
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- Short free-form description the user writes in Edit Profile
-- ("I'm a foodie and always looking for a chill vibe…"). Capped at
-- 140 characters server-side so a misbehaving client can't store a
-- paragraph; client enforces the same limit.
alter table users
  add column if not exists bio text not null default '';

alter table users
  drop constraint if exists users_bio_length_check;

alter table users
  add constraint users_bio_length_check check (char_length(bio) <= 140);
