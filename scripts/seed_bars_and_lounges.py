#!/usr/bin/env python3
"""
Bar/lounge variant of the test-data seed. Generates a focused set
of nightlife-themed places + posts so the feed has real coverage
beyond restaurants. Follows the same engagement spec as
TESTING.md (75–200 likes, 50–200 comments, 1–5 photos, ≥1 vibe
tag per post).

Reads existing FKs from /tmp/existing_users.json and
/tmp/existing_restaurants.json. Writes SQL to stdout; pipe into
the management API split on statement-terminating semicolons.
"""
import json, random, uuid

random.seed(23)

# ---------------------------------------------------------------------------
# Spec knobs (mirror TESTING.md)
# ---------------------------------------------------------------------------
N_NEW_BARS = 30          # bars/lounges/cocktail rooms across many cities
N_NEW_POSTS = 100
LIKES_MIN, LIKES_MAX = 75, 200
COMMENTS_MIN, COMMENTS_MAX = 50, 200
PHOTOS_MIN, PHOTOS_MAX = 1, 5
TAGS_MIN, TAGS_MAX = 1, 3

# ---------------------------------------------------------------------------
# Source data
# ---------------------------------------------------------------------------
BAR_NAME_FIRST = ["The", "Velvet", "Smoke", "Dim", "Last", "Salt", "Lantern",
                  "Slow", "Iron", "Copper", "Marble", "Amber", "Gilded",
                  "Hidden", "Old", "Lazy"]
BAR_NAME_SECOND = ["Hideaway", "Library", "Saloon", "Lounge", "Parlor",
                   "Mirror", "Penny", "Crown", "Vault", "Garden", "Whale",
                   "Owl", "Lantern", "Anchor", "Ember", "Den"]
BAR_SUFFIX = ["", "", " Bar", " Lounge", " Room", " Social", " & Co.",
              " Tavern", " Cocktail Bar", " Speakeasy"]

CUISINES = ["Cocktail Bar", "Wine Bar", "Whiskey Bar", "Lounge",
            "Sports Bar", "Speakeasy", "Beer Garden", "Tiki Bar",
            "Rooftop Bar", "Dive Bar", "Champagne Bar"]

VIBE_TAGS = [
    "happy hour","cocktail bar","late night eats","music vibes",
    "patio season","cozy vibes","date night spots","group hangs",
    "view from the top","natural wine","hidden gem","splurge worthy",
    "outdoor seating","rooftop","jazz night","speakeasy"
]

NOTES = [
    "Best cocktails I've had in a while. Bartender knows their craft.",
    "Vibe is unmatched -- low light, great playlist, perfect pour.",
    "Slipped in for one drink, stayed three hours. No regrets.",
    "Hidden gem, you have to know to look for the door.",
    "Their old fashioned is criminal in the best way.",
    "Rooftop with the right music and the right people. Magic.",
    "Came for the menu, stayed for the staff.",
    "If you like a quiet drink, this is the spot.",
    "Their happy hour is the best deal in town.",
    "No phone signal inside and that was the whole point.",
    "Friday night was packed and somehow still chill.",
    "The wine list rewards repeat visits.",
    "Couches by the window, candles everywhere -- bring a date.",
    "Live jazz on Tuesdays is worth the trip alone.",
    "Their non-alcoholic menu is legitimately better than most cocktail menus.",
    "Best dive in the neighborhood. Don't change a thing.",
]

COMMENT_BODIES = [
    "Adding to my list -- love a good lounge.",
    "Their playlist is unreal.",
    "Best old fashioned in the city imo.",
    "Tried to go last weekend, line was wild.",
    "Thursdays are the move there.",
    "Their happy hour menu is sneaky good.",
    "Bartenders know what they're doing.",
    "Vibes only.",
    "Need to go for a date night soon.",
    "Their natural wine list is dangerous.",
    "Is there a cover after 10?",
    "Reservation needed?",
    "Bookmarked for next month.",
    "Heard the rooftop closes early -- true?",
    "Their non-alc menu is legit.",
    "Live music every weekend?",
    "How loud is it usually?",
    "Going Friday, who's in?",
    "Best for a small group?",
    "Followed for more spots like this.",
    "The lighting alone is worth it.",
    "Their bar snacks slap.",
    "Heard parking is brutal -- any tips?",
    "Definitely a date-night spot.",
]

# Bar / cocktail / dim-lit Unsplash photos (free to use).
BAR_PHOTOS = [
    "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&q=80",
    "https://images.unsplash.com/photo-1575444758702-4a6b9222336e?w=1200&q=80",
    "https://images.unsplash.com/photo-1470337458703-46ad1756a187?w=1200&q=80",
    "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=1200&q=80",
    "https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=1200&q=80",
    "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80",
    "https://images.unsplash.com/photo-1543007630-9710e4a00a20?w=1200&q=80",
    "https://images.unsplash.com/photo-1545438102-799c3991ffb2?w=1200&q=80",
    "https://images.unsplash.com/photo-1516997121675-4c2d1684aa3e?w=1200&q=80",
    "https://images.unsplash.com/photo-1538488881038-e252a119ace7?w=1200&q=80",
    "https://images.unsplash.com/photo-1467810563316-b5476525c0f9?w=1200&q=80",
    "https://images.unsplash.com/photo-1525268771113-32d9e9021a97?w=1200&q=80",
    "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80",
    "https://images.unsplash.com/photo-1568644396922-5c3bfae12521?w=1200&q=80",
    "https://images.unsplash.com/photo-1578922746465-3a80a228f223?w=1200&q=80",
    "https://images.unsplash.com/photo-1485872299712-e6cd58c5f8d6?w=1200&q=80",
]

US_CITIES = [
    ("New York", "NY"), ("Brooklyn", "NY"),
    ("Los Angeles", "CA"), ("San Francisco", "CA"), ("Oakland", "CA"),
    ("Seattle", "WA"), ("Portland", "OR"),
    ("Denver", "CO"), ("Austin", "TX"), ("Houston", "TX"), ("Dallas", "TX"),
    ("Chicago", "IL"), ("Minneapolis", "MN"), ("Detroit", "MI"),
    ("Pittsburgh", "PA"), ("Philadelphia", "PA"), ("Washington", "DC"),
    ("Charlotte", "NC"), ("Nashville", "TN"), ("Atlanta", "GA"),
    ("Miami", "FL"), ("Orlando", "FL"), ("New Orleans", "LA"),
    ("Boston", "MA"), ("Providence", "RI"),
    ("Salt Lake City", "UT"), ("Las Vegas", "NV"), ("Phoenix", "AZ"),
]

def make_bar_name(rng: random.Random) -> str:
    style = rng.random()
    if style < 0.45:
        return rng.choice(BAR_NAME_FIRST) + " " + rng.choice(BAR_NAME_SECOND) + rng.choice(BAR_SUFFIX)
    return rng.choice(BAR_NAME_SECOND) + rng.choice(BAR_SUFFIX)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def esc(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"

def pg_text_array(items):
    inner = ",".join(esc(x) for x in items)
    return f"ARRAY[{inner}]::text[]"

# ---------------------------------------------------------------------------
# Existing ids
# ---------------------------------------------------------------------------
existing_users = [row["id"] for row in json.load(open("/tmp/existing_users.json"))]

# ---------------------------------------------------------------------------
# 1. Bars / lounges
# ---------------------------------------------------------------------------
new_bars = []
seen_names = set()
for _ in range(N_NEW_BARS):
    for _ in range(20):
        name = make_bar_name(random)
        if name not in seen_names:
            seen_names.add(name)
            break
    city, state = random.choice(US_CITIES)
    new_bars.append({
        "id": str(uuid.uuid4()),
        "name": name,
        "cuisine": random.choice(CUISINES),
        "location": f"{city}, {state}",
        "rating": round(random.uniform(3.9, 4.9), 1),
        "price_level": random.randint(2, 4),
        "image_url": random.choice(BAR_PHOTOS),
    })

# ---------------------------------------------------------------------------
# 2. Posts
# ---------------------------------------------------------------------------
bar_ids = [b["id"] for b in new_bars]
new_posts = []
for _ in range(N_NEW_POSTS):
    new_posts.append({
        "id": str(uuid.uuid4()),
        "user_id": random.choice(existing_users),
        "restaurant_id": random.choice(bar_ids),
        "note": random.choice(NOTES),
        "vibe_tags": random.sample(VIBE_TAGS, random.randint(TAGS_MIN, TAGS_MAX)),
        "image_urls": random.sample(BAR_PHOTOS, random.randint(PHOTOS_MIN, PHOTOS_MAX)),
    })

# ---------------------------------------------------------------------------
# Emit SQL
# ---------------------------------------------------------------------------
print("-- ============================================================")
print(f"-- Seed: {N_NEW_BARS} bars/lounges + {N_NEW_POSTS} posts")
print(f"-- Likes {LIKES_MIN}-{LIKES_MAX}, comments {COMMENTS_MIN}-{COMMENTS_MAX} per post.")
print("-- See TESTING.md for the contract.")
print("-- ============================================================\n")

# Restaurants
print("-- Bars / lounges")
vals = [
    f"('{b['id']}'::uuid, {esc(b['name'])}, {esc(b['cuisine'])}, {esc(b['location'])}, {b['rating']}, {b['price_level']}, {esc(b['image_url'])})"
    for b in new_bars
]
print("insert into restaurants (id, name, cuisine, location, rating, price_level, image_url) values")
print(",\n".join(vals) + ";\n")

# Posts
print("-- Posts")
post_rows = [
    f"('{p['id']}'::uuid, '{p['user_id']}'::uuid, '{p['restaurant_id']}'::uuid, {esc(p['note'])}, {pg_text_array(p['vibe_tags'])}, {pg_text_array(p['image_urls'])})"
    for p in new_posts
]
print("insert into posts (id, user_id, restaurant_id, note, vibe_tags, image_urls) values")
print(",\n".join(post_rows) + ";\n")

# Likes
print("-- Likes")
like_rows = []
for p in new_posts:
    pool = [u for u in existing_users if u != p["user_id"]]
    k = random.randint(LIKES_MIN, min(LIKES_MAX, len(pool)))
    likers = random.sample(pool, k)
    for lk in likers:
        like_rows.append(f"('{lk}'::uuid, '{p['id']}'::uuid)")
LCHUNK = 2000
for i in range(0, len(like_rows), LCHUNK):
    print("insert into likes (user_id, post_id) values")
    print(",\n".join(like_rows[i:i+LCHUNK]) + "\non conflict do nothing;\n")

# Comments — keep top-level only here so a single chunked INSERT
# never has to satisfy a parent_comment_id FK in the same statement
# the parent was inserted in. (See seed_test_data.py for the threaded
# variant; the bar variant favors reliability over depth.)
print("-- Comments")
comment_rows = []
for p in new_posts:
    n = random.randint(COMMENTS_MIN, COMMENTS_MAX)
    for _ in range(n):
        cid = str(uuid.uuid4())
        author = random.choice([u for u in existing_users if u != p["user_id"]])
        body = random.choice(COMMENT_BODIES)
        comment_rows.append(
            f"('{cid}'::uuid, '{p['id']}'::uuid, '{author}'::uuid, {esc(body)}, NULL)"
        )
CCHUNK = 2000
for i in range(0, len(comment_rows), CCHUNK):
    print("insert into comments (id, post_id, user_id, text, parent_comment_id) values")
    print(",\n".join(comment_rows[i:i+CCHUNK]) + ";\n")
