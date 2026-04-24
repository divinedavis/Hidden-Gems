-- ============================================================
-- Hidden Gems — per-post images
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- Photos the poster picked when creating a recommendation. First
-- entry is the cover; the feed view coalesces it with the
-- restaurant's own image_url so newly-added restaurants light up
-- with the first poster's photo.
alter table posts
  add column if not exists image_urls text[] not null default '{}';

-- Rebuild the feed view so image_url is "post cover, else restaurant
-- cover". Clients don't need to change — the column is still a
-- single text.
drop view if exists feed cascade;
create view feed as
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
    coalesce((p.image_urls)[1], r.image_url) as image_url,
    (select count(*) from likes l where l.post_id = p.id) as like_count,
    (select count(*) from comments c where c.post_id = p.id) as comment_count
  from posts p
  join users u on u.id = p.user_id
  join restaurants r on r.id = p.restaurant_id
  order by p.created_at desc;
