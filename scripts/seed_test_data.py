#!/usr/bin/env python3
"""
Seed the Hidden Gems test environment. Follows the spec in
../TESTING.md — if that file changes, update the constants here too.

Current run produces:
  - 100 new test users (profile pic + bio on every one) — keeps the
    test-user pool large enough to supply 200 distinct likers per
    post.
  - 150 new restaurants spread across 60+ US cities.
  - 1,000 new posts from the expanded user pool against any seeded
    restaurant, each with:
      * 1–5 photos
      * 1–3 vibe tags
      * 75–200 distinct likers
      * 50–200 comments (half top-level, half threaded replies)

Reads existing FKs from /tmp/existing_users.json and
/tmp/existing_restaurants.json so generated posts reference real rows.
Writes SQL to stdout; pipe into the management API (splitting on
statement-terminating semicolons) to apply.
"""
import json, random, uuid

random.seed(11)

# ---------------------------------------------------------------------------
# Spec knobs (mirror TESTING.md)
# ---------------------------------------------------------------------------
N_NEW_USERS = 100
N_NEW_RESTAURANTS = 150
N_NEW_POSTS = 1000

LIKES_MIN, LIKES_MAX = 75, 200
COMMENTS_MIN, COMMENTS_MAX = 50, 200
PHOTOS_MIN, PHOTOS_MAX = 1, 5
TAGS_MIN, TAGS_MAX = 1, 3

# ---------------------------------------------------------------------------
# Source data
# ---------------------------------------------------------------------------
FIRST = ['Alex','Jordan','Taylor','Morgan','Casey','Riley','Avery','Quinn',
        'Rowan','Sage','Blake','Cameron','Drew','Emerson','Finley','Hayden',
        'Jamie','Kai','Logan','Parker','Reese','Skyler','Tatum','Remy',
        'Nico','Micah','Lennon','Sawyer','Kendall','Emery','Bailey','River',
        'Dakota','Phoenix','Winter','Wren','Rose','Bennett','Paxton','Zion',
        'Atlas','Clay','Kit','Brooke','Mila','Leo','Hazel','Theo','Nora','Jude',
        'Ivy','Eden','Milo','Arlo','Silas','Juno','Cleo','Nova','Esme','Felix',
        'Asher','Ezra','August','Wilder','Ember','Linus','Rafe','Callum','Selah','Tess']

LAST = ['Lopez','Gupta','Chen','Miller','Clark','Lewis','Walker','Hall',
        'Allen','Young','King','Wright','Scott','Torres','Nguyen','Hill',
        'Flores','Adams','Baker','Carter','Mitchell','Roberts','Phillips','Evans',
        'Turner','Morgan','Cooper','Murphy','Rivera','Brooks','Price','Reed',
        'Cook','Bell','Kelly','Howard','Ward','Cox','Peterson','Gray',
        'Ramirez','James','Watson','Russell','Bennett','Sanders','Foster','Hughes','Powell','Long',
        'Kim','Patel','Singh','Khan','Shah','Ali','Cohen','Kaplan','Nakamura','Tanaka',
        'Park','Sato','Ito','Garcia','Martinez','Hernandez','Rivera','Ortiz','Vargas','Castro']

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
    "music vibes","natural wine","chef driven","neighborhood staple",
    "outdoor seating","kid friendly","romantic dinner","business lunch"
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
    "Found my new regular spot.",
    "The kind of meal that ends with 'we have to come back'.",
    "Unreal value for what you get.",
    "Weekday reservation, empty dining room, perfection.",
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
    "How's the service there?",
    "Ordered everything on the menu last time, worth it.",
    "Saving this for my anniversary dinner.",
    "Their wine list is criminally underrated.",
    "I still dream about their pasta.",
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
    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1200&q=80",
    "https://images.unsplash.com/photo-1550547660-d9450f859349?w=1200&q=80",
    "https://images.unsplash.com/photo-1559847844-5315695dadae?w=1200&q=80",
    "https://images.unsplash.com/photo-1555244162-803834f70033?w=1200&q=80",
]

# 60 US cities across coasts, south, midwest, mountain, PNW.
US_CITIES = [
    ("New York", "NY"), ("Brooklyn", "NY"), ("Queens", "NY"), ("Rochester", "NY"),
    ("Los Angeles", "CA"), ("San Francisco", "CA"), ("Oakland", "CA"),
    ("San Diego", "CA"), ("Sacramento", "CA"), ("San Jose", "CA"),
    ("Seattle", "WA"), ("Portland", "OR"),
    ("Denver", "CO"), ("Boulder", "CO"),
    ("Austin", "TX"), ("Houston", "TX"), ("Dallas", "TX"), ("San Antonio", "TX"),
    ("Chicago", "IL"), ("Minneapolis", "MN"), ("Madison", "WI"),
    ("Detroit", "MI"), ("Ann Arbor", "MI"),
    ("Cleveland", "OH"), ("Columbus", "OH"), ("Cincinnati", "OH"),
    ("Pittsburgh", "PA"), ("Philadelphia", "PA"),
    ("Baltimore", "MD"), ("Washington", "DC"),
    ("Richmond", "VA"), ("Arlington", "VA"),
    ("Raleigh", "NC"), ("Charlotte", "NC"), ("Durham", "NC"), ("Asheville", "NC"),
    ("Nashville", "TN"), ("Memphis", "TN"), ("Knoxville", "TN"),
    ("Atlanta", "GA"), ("Savannah", "GA"),
    ("Charleston", "SC"), ("Greenville", "SC"),
    ("Miami", "FL"), ("Orlando", "FL"), ("Tampa", "FL"), ("Jacksonville", "FL"),
    ("New Orleans", "LA"), ("Baton Rouge", "LA"),
    ("Birmingham", "AL"), ("Little Rock", "AR"),
    ("Boston", "MA"), ("Cambridge", "MA"), ("Providence", "RI"),
    ("New Haven", "CT"), ("Hartford", "CT"),
    ("Burlington", "VT"), ("Portland", "ME"),
    ("Kansas City", "MO"), ("St. Louis", "MO"),
    ("Omaha", "NE"), ("Des Moines", "IA"),
    ("Salt Lake City", "UT"), ("Boise", "ID"),
    ("Las Vegas", "NV"), ("Reno", "NV"),
    ("Phoenix", "AZ"), ("Tucson", "AZ"),
    ("Albuquerque", "NM"), ("Santa Fe", "NM"),
    ("Honolulu", "HI"),
]

CUISINES = [
    "Italian", "Mexican", "Japanese", "Korean", "Thai", "Chinese",
    "Vietnamese", "Indian", "Mediterranean", "French", "American",
    "Southern", "Soul Food", "BBQ", "Seafood", "Steakhouse", "Pizza",
    "Burger", "New American", "Californian",
]

NAME_FIRST = [
    "Little", "Big", "The", "Blue", "Red", "Golden", "Silver", "Copper",
    "Wild", "Quiet", "Lazy", "Old", "New", "High", "Low", "Salt",
    "Sugar", "Smoke", "Fire", "Honey", "Pine", "Olive", "Cedar", "Oak",
    "Ivy", "Maple", "Bay",
]

NAME_SECOND = [
    "Horse", "Owl", "Fox", "Wolf", "Lark", "Crow", "Cat", "Bear",
    "Table", "Kitchen", "House", "Dock", "Lantern", "Barrel", "Harbor",
    "Market", "Larder", "Alley", "Bridge", "Pantry", "Grove", "Garden",
    "Room", "Oven", "Spoon", "Pickle",
]

FIRSTNAME_STYLE = ["Lena's", "Marco's", "Tommy's", "Ruby's", "Nora's", "Ezra's",
                   "Otis's", "Pearl's", "Cass's", "Harlem's", "Arthur's",
                   "Enzo's", "Ofelia's", "Raul's", "Dottie's", "Margo's",
                   "Finch's", "Lula's", "Paolo's", "Vera's"]

SUFFIX_STYLE = [" & Co.", " Supper Club", " House", " Bistro", " Trattoria",
                " Grill", " Cantina", " Brasserie", " Kitchen", " Diner",
                " Noodle Bar", " Osteria", " Tavern", " Cafe", " Room"]

def make_restaurant_name(rng: random.Random) -> str:
    style = rng.random()
    if style < 0.25:
        return rng.choice(FIRSTNAME_STYLE)
    if style < 0.55:
        return f"{rng.choice(NAME_FIRST)} {rng.choice(NAME_SECOND)}"
    if style < 0.75:
        return f"{rng.choice(NAME_FIRST)} {rng.choice(NAME_SECOND)}{rng.choice(SUFFIX_STYLE)}"
    return f"{rng.choice(NAME_SECOND)}{rng.choice(SUFFIX_STYLE)}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def esc(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"

def pg_text_array(items):
    inner = ",".join(esc(x) for x in items)
    return f"ARRAY[{inner}]::text[]"

# ---------------------------------------------------------------------------
# Existing ids + handles from /tmp/existing_*.json
# ---------------------------------------------------------------------------
existing_users = [row["id"] for row in json.load(open("/tmp/existing_users.json"))]
existing_restaurants = [row["id"] for row in json.load(open("/tmp/existing_restaurants.json"))]

# Dedupe new handles + emails against what's already in prod so seed
# runs don't collide with previous seed runs.
try:
    _handles = json.load(open("/tmp/existing_user_handles.json"))
    existing_usernames = {row["username"] for row in _handles if row.get("username")}
    existing_emails    = {row["email"]    for row in _handles if row.get("email")}
except (FileNotFoundError, json.JSONDecodeError):
    existing_usernames, existing_emails = set(), set()

# ---------------------------------------------------------------------------
# 1. Users
# ---------------------------------------------------------------------------
used_usernames = set(existing_usernames)
used_emails    = set(existing_emails)
new_users = []
for i in range(N_NEW_USERS):
    first = random.choice(FIRST)
    last  = random.choice(LAST)
    full  = f"{first} {last}"
    base  = (first + last).lower()
    un    = f"@{base[:12]}"
    suf   = 0
    while un in used_usernames:
        suf += 1
        un = f"@{base[:10]}s{suf}"
    used_usernames.add(un)
    email = f"{base}{i}.seed2@example.com"
    esuf = 0
    while email in used_emails:
        esuf += 1
        email = f"{base}{i}.seed2_{esuf}@example.com"
    used_emails.add(email)
    pic_kind = random.choice(["men", "women"])
    pic_num  = random.randint(1, 90)
    uid = str(uuid.uuid4())
    new_users.append({
        "id": uid,
        "name": full,
        "username": un,
        "email": email,
        "profile_image_url": f"https://randomuser.me/api/portraits/{pic_kind}/{pic_num}.jpg",
        "bio": random.choice(BIOS),
    })

# ---------------------------------------------------------------------------
# 2. Restaurants
# ---------------------------------------------------------------------------
new_restaurants = []
used_names = set()
for _ in range(N_NEW_RESTAURANTS):
    name = ""
    for _ in range(30):
        candidate = make_restaurant_name(random)
        if candidate not in used_names:
            name = candidate
            used_names.add(name)
            break
    if not name:
        name = make_restaurant_name(random) + " " + str(random.randint(1, 99))
        used_names.add(name)
    city, state = random.choice(US_CITIES)
    location = f"{city}, {state}"
    cuisine = random.choice(CUISINES)
    rating  = round(random.uniform(3.8, 4.9), 1)
    price   = random.randint(1, 4)
    image   = random.choice(FOOD_PHOTOS)
    new_restaurants.append({
        "id": str(uuid.uuid4()),
        "name": name,
        "cuisine": cuisine,
        "location": location,
        "rating": rating,
        "price_level": price,
        "image_url": image,
    })

# ---------------------------------------------------------------------------
# 3. Posts
# ---------------------------------------------------------------------------
all_users = [u["id"] for u in new_users] + existing_users
all_restaurants = [r["id"] for r in new_restaurants] + existing_restaurants

new_posts = []
for _ in range(N_NEW_POSTS):
    author = random.choice(all_users)
    restaurant = random.choice(all_restaurants)
    photos = random.sample(FOOD_PHOTOS, random.randint(PHOTOS_MIN, PHOTOS_MAX))
    tags   = random.sample(VIBE_TAGS, random.randint(TAGS_MIN, TAGS_MAX))
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
print(f"-- Seed: {N_NEW_USERS} users, {N_NEW_RESTAURANTS} restaurants, {N_NEW_POSTS} posts")
print(f"-- Likes: {LIKES_MIN}-{LIKES_MAX} per post, distinct likers")
print(f"-- Comments: {COMMENTS_MIN}-{COMMENTS_MAX} per post")
print("-- See TESTING.md for the spec.")
print("-- ============================================================\n")

# Users
print("-- Users")
vals = [
    f"('{u['id']}'::uuid, {esc(u['name'])}, {esc(u['username'])}, {esc(u['email'])}, {esc(u['profile_image_url'])}, {esc(u['bio'])})"
    for u in new_users
]
print("insert into users (id, name, username, email, profile_image_url, bio) values")
print(",\n".join(vals) + ";\n")

# Restaurants
print("-- Restaurants")
vals = [
    f"('{r['id']}'::uuid, {esc(r['name'])}, {esc(r['cuisine'])}, {esc(r['location'])}, {r['rating']}, {r['price_level']}, {esc(r['image_url'])})"
    for r in new_restaurants
]
print("insert into restaurants (id, name, cuisine, location, rating, price_level, image_url) values")
print(",\n".join(vals) + ";\n")

# Posts (chunked to stay under the 1MB request ceiling)
print("-- Posts")
post_rows = [
    f"('{p['id']}'::uuid, '{p['user_id']}'::uuid, '{p['restaurant_id']}'::uuid, {esc(p['note'])}, {pg_text_array(p['vibe_tags'])}, {pg_text_array(p['image_urls'])})"
    for p in new_posts
]
CHUNK = 500
for i in range(0, len(post_rows), CHUNK):
    print("insert into posts (id, user_id, restaurant_id, note, vibe_tags, image_urls) values")
    print(",\n".join(post_rows[i:i+CHUNK]) + ";\n")

# Likes — distinct likers per post
print("-- Likes")
like_rows = []
for p in new_posts:
    pool = [u for u in all_users if u != p["user_id"]]
    k = random.randint(LIKES_MIN, min(LIKES_MAX, len(pool)))
    likers = random.sample(pool, k)
    for lk in likers:
        like_rows.append(f"('{lk}'::uuid, '{p['id']}'::uuid)")
LCHUNK = 2000
for i in range(0, len(like_rows), LCHUNK):
    print("insert into likes (user_id, post_id) values")
    print(",\n".join(like_rows[i:i+LCHUNK]) + "\non conflict do nothing;\n")

# Comments — half top-level, half replies
print("-- Comments")
all_comment_rows = []
for p in new_posts:
    n = random.randint(COMMENTS_MIN, COMMENTS_MAX)
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

CCHUNK = 2000
for i in range(0, len(all_comment_rows), CCHUNK):
    print("insert into comments (id, post_id, user_id, text, parent_comment_id) values")
    print(",\n".join(all_comment_rows[i:i+CCHUNK]) + ";\n")
