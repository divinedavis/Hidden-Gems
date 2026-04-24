#!/usr/bin/env python3
"""
Generate SQL to seed the Hidden Gems test environment with:
  - 50 new users (profile pic + bio on each)
  - 100 new posts from those users + existing users
    * 1-5 photos per post
    * >=1 vibe tag per post
    * >=101 likes per post
    * >=31 comments per post (including some replies)

Reads existing users/restaurants from /tmp/existing_*.json.
Writes SQL to stdout.
"""
import json, random, uuid

random.seed(7)

# ---------------------------------------------------------------------------
# Source data
# ---------------------------------------------------------------------------
FIRST = ['Alex','Jordan','Taylor','Morgan','Casey','Riley','Avery','Quinn',
        'Rowan','Sage','Blake','Cameron','Drew','Emerson','Finley','Hayden',
        'Jamie','Kai','Logan','Parker','Reese','Skyler','Tatum','Remy',
        'Nico','Micah','Lennon','Sawyer','Kendall','Emery','Bailey','River',
        'Dakota','Phoenix','Winter','Wren','Rose','Bennett','Paxton','Zion',
        'Atlas','Clay','Kit','Brooke','Mila','Leo','Hazel','Theo','Nora','Jude']

LAST = ['Lopez','Gupta','Chen','Miller','Clark','Lewis','Walker','Hall',
        'Allen','Young','King','Wright','Scott','Torres','Nguyen','Hill',
        'Flores','Adams','Baker','Carter','Mitchell','Roberts','Phillips','Evans',
        'Turner','Morgan','Cooper','Murphy','Rivera','Brooks','Price','Reed',
        'Cook','Bell','Kelly','Howard','Ward','Cox','Peterson','Gray',
        'Ramirez','James','Watson','Russell','Bennett','Sanders','Foster','Hughes','Powell','Long']

BIOS = [
    "Foodie always looking for a chill vibe.",
    "NYC-based restaurant lover and taco hunter.",
    "Brunch enthusiast, coffee addict.",
    "Pasta is my love language.",
    "Date night curator for the pickiest friends.",
    "Ramen obsessive, wings explorer.",
    "Local spots only. No tourist traps.",
    "Plant-based but I love a good burger.",
    "Sushi aficionado and cocktail explorer.",
    "I eat my way through every city I visit.",
    "Weekend brunch, weekday takeout.",
    "Lowkey vibes and hidden gems.",
    "Always down for pizza and a long conversation.",
    "Taco Tuesday, every Tuesday.",
    "Oyster bar at 5 PM, you in?",
    "Best view, best food.",
    "Chef-driven spots only.",
    "Brooklyn born, eating everywhere.",
    "Dim sum on weekends, thai on weeknights.",
    "Wood-fired pizza obsession.",
    "Always on the hunt for the perfect cortado.",
    "Spicy food enthusiast.",
    "Anti-trend, pro-flavor.",
    "Natural wine and small plates.",
    "I know a spot for that.",
]

VIBE_TAGS = [
    "date night spots","lowkey vibes","quick lunch","brunch spots",
    "happy hour","cozy vibes","solo dining","group hangs",
    "late night eats","patio season","cocktail bar","hidden gem",
    "splurge worthy","view from the top","family friendly","quiet corner",
    "music vibes","natural wine","chef driven","neighborhood staple"
]

NOTES = [
    "This spot blew my expectations away. Go hungry.",
    "Book ahead -- fills up fast for good reason.",
    "The pasta here ruined me for any other place.",
    "Perfect for a low-key weeknight dinner.",
    "Great vibe, better food. Can't ask for more.",
    "Came here on a whim and it completely delivered.",
    "Every bite was a chef's kiss moment.",
    "If you only try one thing, make it the special.",
    "A neighborhood favorite for a reason.",
    "Been three times this month. Not sorry.",
    "Service was warm and the food even warmer.",
    "Exactly the kind of place I want to recommend.",
    "Best meal I've had in months.",
    "Cozy, intimate, and the menu rotates perfectly.",
    "Worth every dollar. I'd come back tomorrow.",
    "Bring a date. Thank me later.",
    "This place does simple food right.",
    "Staff knew the menu cold. Great recs.",
    "Bar seats are the move -- watch the kitchen work.",
    "Flavors were bright and thoughtful.",
]

COMMENT_BODIES = [
    "This place is my favorite -- glad you liked it!",
    "Adding this to my list immediately.",
    "Did you try the special? It's insane.",
    "Been wanting to go here. Worth the hype?",
    "I love this spot, the vibe is unmatched.",
    "Going this weekend!",
    "The best in the area imo.",
    "Bar seats or table?",
    "Obsessed with their dessert menu.",
    "Tried it last week -- agree 100%.",
    "What time did you go? Is it busy?",
    "Need to book or can I walk in?",
    "So fun -- love this place.",
    "Ate here on my birthday, unreal.",
    "Great rec, thanks for posting.",
    "Is it good for a group of 6?",
    "Their cocktails are dangerous (in a good way).",
    "Staff was so warm when I went.",
    "Absolute gem.",
    "Followed for more spots like this!",
    "The photos don't do it justice.",
    "Their brunch is also amazing.",
    "Need to try this. Any dish I shouldn't miss?",
    "Love your notes on this one.",
    "This is why I love this app.",
    "Been there! Agree.",
    "Bookmarking for next trip.",
    "Their lighting is so good for photos lol.",
    "Wait time on a Friday night?",
    "Did you sit inside or out?",
    "Great find!",
    "Chef was hands-on when I visited, super cool.",
    "Wait, this is near me?",
    "How's the service there?",
    "Ordered everything on the menu last time, worth it.",
]

FOOD_PHOTOS = [
    "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1200&q=80",
    "https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=1200&q=80",
    "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=1200&q=80",
    "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=80",
    "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=1200&q=80",
    "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=1200&q=80",
    "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&q=80",
    "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=1200&q=80",
    "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=1200&q=80",
    "https://images.unsplash.com/photo-1464306076886-debca5e8a6b0?w=1200&q=80",
    "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=1200&q=80",
    "https://images.unsplash.com/photo-1600891964092-4316c288032e?w=1200&q=80",
    "https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=1200&q=80",
    "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=1200&q=80",
    "https://images.unsplash.com/photo-1551218808-94e220e084d2?w=1200&q=80",
    "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=1200&q=80",
    "https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=1200&q=80",
    "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=80",
    "https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=1200&q=80",
    "https://images.unsplash.com/photo-1555072956-7758afb20e8f?w=1200&q=80",
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def esc(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"

def pg_text_array(items):
    inner = ",".join(esc(x) for x in items)
    return f"ARRAY[{inner}]::text[]"

# ---------------------------------------------------------------------------
# Existing ids (loaded from fetched JSON)
# ---------------------------------------------------------------------------
existing_users = [row["id"] for row in json.load(open("/tmp/existing_users.json"))]
existing_restaurants = [row["id"] for row in json.load(open("/tmp/existing_restaurants.json"))]

# ---------------------------------------------------------------------------
# 1. Generate 50 new users (with unique usernames + emails)
# ---------------------------------------------------------------------------
used_usernames = set()
new_users = []
for i in range(50):
    first = random.choice(FIRST)
    last  = random.choice(LAST)
    full  = f"{first} {last}"
    base  = (first + last).lower()
    un    = f"@{base[:12]}"
    suf   = 0
    while un in used_usernames:
        suf += 1
        un = f"@{base[:10]}{suf}"
    used_usernames.add(un)
    pic_kind = random.choice(["men", "women"])
    pic_num  = random.randint(1, 90)
    uid = str(uuid.uuid4())
    new_users.append({
        "id": uid,
        "name": full,
        "username": un,
        "email": f"{base}{i}.seed@example.com",
        "profile_image_url": f"https://randomuser.me/api/portraits/{pic_kind}/{pic_num}.jpg",
        "bio": random.choice(BIOS),
    })

# ---------------------------------------------------------------------------
# 2. Generate 100 posts — authors round-robin through new users plus
#    half drawn from existing users (so some test accounts have posts
#    too).
# ---------------------------------------------------------------------------
all_users = [u["id"] for u in new_users] + existing_users
new_posts = []
for _ in range(100):
    author = random.choice([u["id"] for u in new_users] + random.sample(existing_users, 15))
    restaurant = random.choice(existing_restaurants)
    photos = random.sample(FOOD_PHOTOS, random.randint(1, 5))
    tags   = random.sample(VIBE_TAGS, random.randint(1, 3))
    note   = random.choice(NOTES)
    new_posts.append({
        "id": str(uuid.uuid4()),
        "user_id": author,
        "restaurant_id": restaurant,
        "note": note,
        "vibe_tags": tags,
        "image_urls": photos,
    })

# ---------------------------------------------------------------------------
# Emit SQL
# ---------------------------------------------------------------------------
print("-- ============================================================")
print(f"-- Seed: 50 users + 100 posts (>=101 likes, >=31 comments each)")
print("-- ============================================================\n")

# Users
print("-- Users")
vals = [f"('{u['id']}'::uuid, {esc(u['name'])}, {esc(u['username'])}, {esc(u['email'])}, {esc(u['profile_image_url'])}, {esc(u['bio'])})" for u in new_users]
print("insert into users (id, name, username, email, profile_image_url, bio) values")
print(",\n".join(vals) + ";\n")

# Posts
print("-- Posts")
vals = []
for p in new_posts:
    vals.append(
        f"('{p['id']}'::uuid, '{p['user_id']}'::uuid, '{p['restaurant_id']}'::uuid, "
        f"{esc(p['note'])}, {pg_text_array(p['vibe_tags'])}, {pg_text_array(p['image_urls'])})"
    )
print("insert into posts (id, user_id, restaurant_id, note, vibe_tags, image_urls) values")
print(",\n".join(vals) + ";\n")

# Likes — 101-150 per post, sampled from any user except the author.
print("-- Likes (>=101 per post)")
like_rows = []
for p in new_posts:
    pool = [u for u in all_users if u != p["user_id"]]
    k = random.randint(101, min(150, len(pool)))
    likers = random.sample(pool, k)
    for lk in likers:
        like_rows.append(f"('{lk}'::uuid, '{p['id']}'::uuid)")
# Chunk the INSERT to keep each statement reasonable.
CHUNK = 2000
for i in range(0, len(like_rows), CHUNK):
    print("insert into likes (user_id, post_id) values")
    print(",\n".join(like_rows[i:i+CHUNK]) + "\non conflict do nothing;\n")

# Comments — 31-45 per post, half top-level and half replies to
# random top-level comments on the same post.
print("-- Comments (>=31 per post)")
top_level_by_post = {}
all_comment_rows = []
for p in new_posts:
    n = random.randint(31, 45)
    top_n = n // 2 + 1
    reply_n = n - top_n
    top_ids = []
    for _ in range(top_n):
        cid = str(uuid.uuid4())
        author = random.choice([u for u in all_users if u != p["user_id"]])
        body = random.choice(COMMENT_BODIES)
        top_ids.append(cid)
        all_comment_rows.append(
            f"('{cid}'::uuid, '{p['id']}'::uuid, '{author}'::uuid, {esc(body)}, NULL)"
        )
    for _ in range(reply_n):
        cid = str(uuid.uuid4())
        author = random.choice([u for u in all_users if u != p["user_id"]])
        parent = random.choice(top_ids)
        body = random.choice(COMMENT_BODIES)
        all_comment_rows.append(
            f"('{cid}'::uuid, '{p['id']}'::uuid, '{author}'::uuid, {esc(body)}, '{parent}'::uuid)"
        )
    top_level_by_post[p["id"]] = top_ids

# Insert comments in chunks.
for i in range(0, len(all_comment_rows), CHUNK):
    print("insert into comments (id, post_id, user_id, text, parent_comment_id) values")
    print(",\n".join(all_comment_rows[i:i+CHUNK]) + ";\n")
