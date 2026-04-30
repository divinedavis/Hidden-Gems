-- ============================================================
-- Hidden Gems — cached recommendation_count + badge views
-- Adds a per-user post counter that backs the "Recommender"
-- badge tiers (1 / 10 / 50 / 100 / 500) on profiles, and a view
-- that the Search "Top Recommenders" filter queries to find
-- restaurants posted by users at or above a chosen tier.
-- ============================================================

-- 1. Cached count column on users. Trigger keeps it in sync so
--    we don't re-aggregate posts every time a profile renders.
alter table users
  add column if not exists recommendation_count integer not null default 0;

-- 2. Backfill from existing posts. Safe to re-run.
update users u
set recommendation_count = sub.cnt
from (
  select user_id, count(*)::int as cnt
  from posts
  group by user_id
) sub
where u.id = sub.user_id;

-- Zero out any users with no posts so the column is fully accurate
-- after the backfill (the join above only covers users with posts).
update users
set recommendation_count = 0
where id not in (select distinct user_id from posts)
  and recommendation_count <> 0;

-- 3. Trigger: increment on insert, decrement on delete. We clamp
--    at 0 because a stray double-delete shouldn't drive the count
--    negative (it's a UI signal, not an audit log).
create or replace function bump_user_recommendation_count() returns trigger
language plpgsql as $$
begin
  if (TG_OP = 'INSERT') then
    update users
      set recommendation_count = recommendation_count + 1
      where id = NEW.user_id;
    return NEW;
  elsif (TG_OP = 'DELETE') then
    update users
      set recommendation_count = greatest(recommendation_count - 1, 0)
      where id = OLD.user_id;
    return OLD;
  end if;
  return null;
end $$;

drop trigger if exists posts_bump_user_count on posts;
create trigger posts_bump_user_count
  after insert or delete on posts
  for each row execute function bump_user_recommendation_count();

-- 4. Re-create user_profiles view to expose recommendation_count.
--    The Swift client decodes this view for both own-profile load
--    (AuthManager.loadProfile) and other-profile live counts
--    (ProfileView.loadLiveCounts).
create or replace view user_profiles as
  select
    u.id,
    u.name,
    u.username,
    u.email,
    u.profile_image_url,
    u.bio,
    u.created_at,
    u.recommendation_count,
    (select count(*) from follows f where f.following_id = u.id) as followers_count,
    (select count(*) from follows f where f.follower_id  = u.id) as following_count
  from users u;

-- 5. View used by Search's "Top Recommenders" filter. For each
--    restaurant we expose the highest poster recommendation_count
--    so the client can do a single .gte filter to surface places
--    posted by users at or above a chosen tier.
create or replace view top_recommended_restaurants as
  select
    p.restaurant_id,
    max(u.recommendation_count) as max_poster_count
  from posts p
  join users u on u.id = p.user_id
  group by p.restaurant_id;
