-- ============================================================
-- Hidden Gems — expose posts.image_urls on the feed view
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- Previous migration (003) only exposed a single coalesced image_url
-- (first post photo, else restaurant cover). For multi-image posts
-- the client needs the full array so the card can render a
-- swipeable carousel of every photo the poster attached.
drop view if exists feed cascade;
create view feed as
  select
    p.id,
    p.note,
    p.created_at,
    p.vibe_tags,
    p.image_urls,
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
