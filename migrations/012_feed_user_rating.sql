-- ============================================================
-- Hidden Gems — expose poster's star rating on the feed view
-- Each post is by a user who's already rated the place (the
-- create form requires `rating >= 1`), but the feed card was
-- showing the community aggregate `restaurants.rating` instead
-- of the poster's own rating. This pulls the per-(user,
-- restaurant) value from the ratings table so the UI can
-- render the stars the poster actually picked.
-- ============================================================

-- user_rating is appended at the end because CREATE OR REPLACE
-- VIEW forbids reordering existing columns. The Swift client
-- selects the view via `.select()` so column order is irrelevant
-- on the wire.
create or replace view feed as
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
    (select count(*) from comments c where c.post_id = p.id) as comment_count,
    (select rating from ratings rt
       where rt.user_id = p.user_id
         and rt.restaurant_id = p.restaurant_id) as user_rating
  from posts p
  join users u on u.id = p.user_id
  join restaurants r on r.id = p.restaurant_id
  order by p.created_at desc;
