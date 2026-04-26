-- ============================================================
-- Hidden Gems — Apple Maps place identifiers
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- When the Add Place picker pulls a POI from Apple Maps, we
-- upsert a `restaurants` row keyed on the Apple place id so
-- subsequent posts about the same spot reuse the row instead of
-- creating duplicates. Manually-added places leave the column
-- null. Latitude/longitude are stashed alongside so the client
-- can render coordinates / map previews without a second lookup.
alter table restaurants add column if not exists apple_place_id text;
alter table restaurants add column if not exists latitude double precision;
alter table restaurants add column if not exists longitude double precision;

-- Real UNIQUE constraint (not a partial index) so PostgREST's
-- ON CONFLICT (apple_place_id) upsert can match it. Postgres treats
-- NULLs as distinct in unique constraints, so multiple manually-added
-- rows with null apple_place_id still coexist.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'restaurants_apple_place_id_key'
      and conrelid = 'restaurants'::regclass
  ) then
    -- drop the older partial index if it's still around
    execute 'drop index if exists restaurants_apple_place_id_key';
    alter table restaurants
      add constraint restaurants_apple_place_id_key unique (apple_place_id);
  end if;
end $$;
