-- ============================================================
-- Hidden Gems — Supabase Schema
-- Run this in the Supabase SQL Editor
-- ============================================================

-- Enable pgvector for AI similarity search
create extension if not exists vector;

-- ============================================================
-- USERS
-- ============================================================
create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  username text unique not null,
  email text unique not null,
  profile_image_url text,
  created_at timestamptz default now()
);

-- ============================================================
-- RESTAURANTS
-- ============================================================
create table if not exists restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cuisine text,
  location text,
  rating numeric(2,1),
  price_level int check (price_level between 1 and 4),
  description text,
  image_url text,
  embedding vector(1536), -- OpenAI/Claude embedding for AI recommendations
  created_at timestamptz default now()
);

-- ============================================================
-- POSTS (recommendations)
-- ============================================================
create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade not null,
  restaurant_id uuid references restaurants(id) on delete cascade not null,
  note text,
  vibe_tags text[] not null default '{}',
  image_urls text[] not null default '{}',
  created_at timestamptz default now()
);

create index if not exists posts_vibe_tags_idx
  on posts using gin (vibe_tags);

-- ============================================================
-- FOLLOWS
-- ============================================================
create table if not exists follows (
  follower_id uuid references users(id) on delete cascade,
  following_id uuid references users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, following_id)
);

-- ============================================================
-- LIKES
-- ============================================================
create table if not exists likes (
  user_id uuid references users(id) on delete cascade,
  post_id uuid references posts(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, post_id)
);

-- ============================================================
-- COMMENTS
-- ============================================================
create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts(id) on delete cascade not null,
  user_id uuid references users(id) on delete cascade not null,
  text text not null,
  created_at timestamptz default now()
);

-- ============================================================
-- COMMENT LIKES
-- ============================================================
create table if not exists comment_likes (
  user_id uuid references users(id) on delete cascade,
  comment_id uuid references comments(id) on delete cascade,
  primary key (user_id, comment_id)
);

-- ============================================================
-- SAVED RESTAURANTS
-- ============================================================
create table if not exists saved_restaurants (
  user_id uuid references users(id) on delete cascade,
  restaurant_id uuid references restaurants(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, restaurant_id)
);

-- ============================================================
-- FEED VIEW — posts with full user + restaurant details
-- ============================================================
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
    coalesce((p.image_urls)[1], r.image_url) as image_url,
    (select count(*) from likes l where l.post_id = p.id) as like_count,
    (select count(*) from comments c where c.post_id = p.id) as comment_count
  from posts p
  join users u on u.id = p.user_id
  join restaurants r on r.id = p.restaurant_id
  order by p.created_at desc;

-- Per-restaurant aggregate of every vibe ever applied to a post
-- about that restaurant. Search tab reads this to filter by vibe.
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

-- ============================================================
-- PGVECTOR — AI restaurant similarity search
-- ============================================================
create or replace function match_restaurants(
  query_embedding vector(1536),
  match_threshold float default 0.7,
  match_count int default 10
)
returns table (
  id uuid,
  name text,
  cuisine text,
  location text,
  rating numeric,
  similarity float
)
language sql stable as $$
  select
    r.id,
    r.name,
    r.cuisine,
    r.location,
    r.rating,
    1 - (r.embedding <=> query_embedding) as similarity
  from restaurants r
  where r.embedding is not null
    and 1 - (r.embedding <=> query_embedding) > match_threshold
  order by similarity desc
  limit match_count;
$$;

-- ============================================================
-- PERSONALIZED FEED — posts from followed users
-- ============================================================
create or replace function get_feed_for_user(p_user_id uuid)
returns table (
  id uuid,
  note text,
  created_at timestamptz,
  user_id uuid,
  user_name text,
  username text,
  restaurant_id uuid,
  restaurant_name text,
  cuisine text,
  location text,
  rating numeric,
  price_level int,
  image_url text,
  like_count bigint,
  comment_count bigint
)
language sql stable as $$
  select
    p.id,
    p.note,
    p.created_at,
    u.id as user_id,
    u.name as user_name,
    u.username,
    r.id as restaurant_id,
    r.name as restaurant_name,
    r.cuisine,
    r.location,
    r.rating,
    r.price_level,
    r.image_url,
    (select count(*) from likes l where l.post_id = p.id) as like_count,
    (select count(*) from comments c where c.post_id = p.id) as comment_count
  from posts p
  join users u on u.id = p.user_id
  join restaurants r on r.id = p.restaurant_id
  where p.user_id in (
    select following_id from follows where follower_id = p_user_id
  )
  or p.user_id = p_user_id
  order by p.created_at desc;
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table users enable row level security;
alter table posts enable row level security;
alter table restaurants enable row level security;
alter table follows enable row level security;
alter table likes enable row level security;
alter table comments enable row level security;
alter table comment_likes enable row level security;
alter table saved_restaurants enable row level security;

-- Anyone can read
create policy "Public read" on users for select using (true);
create policy "Public read" on posts for select using (true);
create policy "Public read" on restaurants for select using (true);
create policy "Public read" on follows for select using (true);
create policy "Public read" on likes for select using (true);
create policy "Public read" on comments for select using (true);
create policy "Public read" on comment_likes for select using (true);
create policy "Public read" on saved_restaurants for select using (true);

-- Authenticated users can write their own data
create policy "Users can insert own profile" on users for insert with check (auth.uid() = id);
create policy "Users can update own profile" on users for update using (auth.uid() = id);
create policy "Users can insert posts" on posts for insert with check (auth.uid() = user_id);
create policy "Users can delete own posts" on posts for delete using (auth.uid() = user_id);
create policy "Users can manage follows" on follows for all using (auth.uid() = follower_id);
create policy "Users can manage likes" on likes for all using (auth.uid() = user_id);
create policy "Users can insert comments" on comments for insert with check (auth.uid() = user_id);
create policy "Users can delete own comments" on comments for delete using (auth.uid() = user_id);
create policy "Users can manage comment likes" on comment_likes for all using (auth.uid() = user_id);
create policy "Users can manage saved" on saved_restaurants for all using (auth.uid() = user_id);
create policy "Anyone can insert restaurants" on restaurants for insert with check (true);
