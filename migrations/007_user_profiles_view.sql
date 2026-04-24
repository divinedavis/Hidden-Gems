-- ============================================================
-- Hidden Gems — profile view with live follower counts
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- Previous builds decoded followers_count / following_count as
-- columns on `users`, but those columns don't exist — so every
-- profile always rendered 0 / 0 regardless of how many follows
-- the user had. Wrap users with a view that derives both counts
-- live from the `follows` table. Client points profile loads at
-- this view instead of `users` directly.
create or replace view user_profiles as
  select
    u.id,
    u.name,
    u.username,
    u.email,
    u.profile_image_url,
    u.bio,
    u.created_at,
    (select count(*) from follows f where f.following_id = u.id) as followers_count,
    (select count(*) from follows f where f.follower_id  = u.id) as following_count
  from users u;
