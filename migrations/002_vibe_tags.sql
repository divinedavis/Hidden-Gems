-- ============================================================
-- Hidden Gems — vibe tags on posts
-- Adds Instagram-style free-form tags + curated vibes
-- ("Date Night Spots", "Quick Lunch", "Late Night Eats",
--  "Lowkey Vibes", "Good for Solo Dining") to posts, and
-- exposes them through the feed + a per-restaurant aggregate
-- so the Search tab can filter restaurants by vibe.
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- 1. Tags column on posts — array of lowercase tag strings.
alter table posts
  add column if not exists vibe_tags text[] not null default '{}';

-- 2. GIN index so `vibe_tags @> array['date night spots']` stays fast
--    as the posts table grows.
create index if not exists posts_vibe_tags_idx
  on posts using gin (vibe_tags);

-- 3. Refresh the feed view so the client sees vibe_tags.
create or replace view feed as
  select
    p.id,
    p.note,
    p.created_at,
    p.vibe_tags,
    u.id as user_id,
    u.name as user_name,
    u.username,
    u.profile_image_url,
    r.id as restaurant_id,
    r.name as restaurant_name,
    r.cuisine,
    r.location,
    r.rating,
    r.price_level,
    r.description,
    r.image_url,
    (select count(*) from likes l where l.post_id = p.id) as like_count,
    (select count(*) from comments c where c.post_id = p.id) as comment_count
  from posts p
  join users u on u.id = p.user_id
  join restaurants r on r.id = p.restaurant_id
  order by p.created_at desc;

-- 4. Per-restaurant aggregate of every vibe ever applied to a
--    post about that restaurant. The Search tab reads this and
--    filters client-side by the selected chip.
create or replace view restaurants_with_vibes as
  select
    r.id,
    r.name,
    r.cuisine,
    r.location,
    r.rating,
    r.price_level,
    r.image_url,
    r.description,
    coalesce(
      (
        select array_agg(distinct tag order by tag)
        from posts p, unnest(p.vibe_tags) as tag
        where p.restaurant_id = r.id
      ),
      '{}'
    ) as vibe_tags
  from restaurants r;
