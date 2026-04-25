# Test-data generation spec

This document is the contract for test-data seeding. Follow it every
time test posts are generated — either by running
`scripts/seed_test_data.py` or by asking Claude to generate test data.
If the requirements here change, update this file first and then the
seed script.

## Users

- Every test user has:
  - A realistic `name` (first + last).
  - A unique `@handle` username.
  - A unique `email`.
  - A non-empty `profile_image_url` (pulled from
    `randomuser.me/api/portraits/…`).
  - A non-empty `bio` sampled from the curated list in the script.
- Seed script keeps the test user pool at a size that supports the
  upper bound of likes per post (currently ≥ 201 users so a 200-like
  post has room for 200 distinct authors excluding the poster).

## Restaurants

- Spread across **at least 50 US cities**, mixing coasts, South,
  Midwest, mountain, and Pacific Northwest.
- Cuisines drawn from a curated list (Italian, Mexican, Japanese,
  Korean, Thai, Chinese, Vietnamese, Indian, Mediterranean, French,
  American, Southern, Soul Food, BBQ, Seafood, Steakhouse, Pizza,
  Burger, New American, Californian).
- `price_level` randomized 1–4, `rating` 3.8–4.9, `image_url`
  populated from the food-photo pool.

## Posts

- Each post has:
  - A `restaurant_id` sampled from any seeded restaurant.
  - A `user_id` sampled across the test-user pool.
  - A short caption from the curated `NOTES` list.
  - **≥ 1 vibe tag** (script picks 1–3 from the curated `VIBE_TAGS`
    list).
  - **Between 1 and 5 photos** stored in `posts.image_urls` (script
    picks `random.sample(FOOD_PHOTOS, random.randint(1, 5))`).
  - **Between 75 and 200 likes**, each from a distinct user (unique
    per `(user_id, post_id)` primary key).
  - **Between 50 and 200 comments**, of which roughly half are
    top-level and half are replies to the post's own top-level
    comments (so threads look lived-in).

## Variants

The default `scripts/seed_test_data.py` produces a generic
restaurants-and-posts batch. Other variants live alongside it for
focused content types — they all follow the same per-post engagement
contract above:

- `scripts/seed_bars_and_lounges.py` — 30 bars/lounges/cocktail
  rooms across many cities, plus 100 posts referencing them. Uses
  bar-themed names, cuisines (Cocktail Bar, Wine Bar, Lounge…),
  vibe tags (happy hour, cocktail bar, rooftop…), and a separate
  cocktail/dim-lit photo pool. Top-level comments only — no
  threaded replies — so the chunked INSERTs never have to satisfy
  a parent_comment_id FK.

When adding a new variant, copy the bars script as a template and
keep the same engagement-spec constants (LIKES_MIN/LIKES_MAX,
COMMENTS_MIN/COMMENTS_MAX, PHOTOS, TAGS).

## Running the seed

```bash
# one-time: fetch existing FKs so the script can reference them
PAT=$(security find-generic-password -s supabase-pat-clockin -w)
REF=ozxvllpdgswxuvelulbm
curl -s -X POST -H "Authorization: Bearer $PAT" -H "Content-Type: application/json" \
  -d '{"query":"select id from users;"}' \
  "https://api.supabase.com/v1/projects/$REF/database/query" > /tmp/existing_users.json
curl -s -X POST -H "Authorization: Bearer $PAT" -H "Content-Type: application/json" \
  -d '{"query":"select id from restaurants;"}' \
  "https://api.supabase.com/v1/projects/$REF/database/query" > /tmp/existing_restaurants.json

python3 scripts/seed_test_data.py > /tmp/seed.sql
# then split into individual INSERTs and POST each to
# https://api.supabase.com/v1/projects/$REF/database/query
```

The script prints SQL to stdout; piping into the management API's
`/database/query` endpoint (split into individual INSERT statements
to stay under the 1 MB request limit) applies everything.

## Scale guardrails

- At 1,000 posts × 200 comments = 200k rows, `fetchAllComments` on
  the client becomes slow. If you regenerate with these numbers,
  either paginate comment fetch per-post or cap the upper bounds in
  this file and in the script together.
- Likes and comments are chunked into 2,000-row INSERTs inside the
  script so each statement stays well under the API request limit.

## Changing the defaults

When the required numbers change (more/fewer users, different
like/comment ranges, new tags, new cities), **edit this file first,
then update `scripts/seed_test_data.py` to match.** Do not change one
without the other.
