-- ============================================================
-- Hidden Gems — indexes that keep the feed view snappy at scale
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- The `feed` view runs two correlated subqueries per post to
-- compute like_count and comment_count. Without an index on
-- likes.post_id and comments.post_id each subquery becomes a full
-- sequential scan of whichever table it's hitting. After seeding
-- 150k likes + 110k comments, a feed SELECT with LIMIT 200 was
-- tripping PostgREST's statement-timeout (57014) and returning
-- nothing. Adding these indexes drops the same query from
-- "timeout" to ~300ms.
create index if not exists likes_post_id_idx on likes (post_id);
create index if not exists comments_post_id_idx on comments (post_id);

-- The view also orders by posts.created_at desc; a dedicated index
-- means the planner can pull the newest 200 without a full sort.
create index if not exists posts_created_at_idx on posts (created_at desc);

analyze likes;
analyze comments;
analyze posts;
