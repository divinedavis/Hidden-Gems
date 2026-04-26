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

-- Partial unique index — enforces uniqueness only when the column
-- is populated, so multiple manually-added rows can coexist.
create unique index if not exists restaurants_apple_place_id_key
  on restaurants (apple_place_id)
  where apple_place_id is not null;
