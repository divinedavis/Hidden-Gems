-- Per-user, per-restaurant star rating (1-5). Editable from the
-- feed card and prefilled in the New Recommendation form so a user
-- can adjust their take on a place without creating a new post.
-- Composite PK + RLS ensure each user has at most one rating per
-- restaurant and can only mutate their own row.
create table if not exists ratings (
  user_id      uuid not null references users(id) on delete cascade,
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  rating       int  not null check (rating between 1 and 5),
  updated_at   timestamptz default now(),
  primary key (user_id, restaurant_id)
);

alter table ratings enable row level security;

create policy "Public read" on ratings for select using (true);
create policy "Users can manage ratings" on ratings for all using (auth.uid() = user_id);
