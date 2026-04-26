#!/usr/bin/env python3
"""Map Overpass JSON dump (/tmp/lancaster.json) to restaurants rows and emit
INSERT SQL on stdout. Skips entries with no name."""
import json, uuid

# OSM amenity → app category
AMENITY_FALLBACK = {
    "cafe": "Cafe",
    "fast_food": "American",     # refined below by cuisine tag
    "restaurant": "American",    # refined below by cuisine tag
    "bar": "Cocktail Bar",
    "pub": "Dive Bar",
    "biergarten": "Beer Garden",
    "nightclub": "Lounge",
    "ice_cream": "Dessert",
    "bakery": "Bakery",
    "food_court": "American",
}

# OSM cuisine tag → app category. Many free-form values, this covers
# the ones I saw in the Lancaster pull plus common siblings.
CUISINE_MAP = {
    "italian": "Italian", "pizza": "Pizza", "mexican": "Mexican",
    "chinese": "Chinese", "japanese": "Japanese", "sushi": "Japanese",
    "korean": "Korean", "thai": "Thai", "vietnamese": "Vietnamese",
    "indian": "Indian", "mediterranean": "Mediterranean",
    "french": "French", "greek": "Greek", "spanish": "Spanish",
    "middle_eastern": "Middle Eastern", "ethiopian": "Ethiopian",
    "brazilian": "Brazilian", "peruvian": "Peruvian",
    "caribbean": "Caribbean", "soul_food": "Soul Food",
    "southern": "Southern", "barbecue": "BBQ", "bbq": "BBQ",
    "seafood": "Seafood", "steak_house": "Steakhouse",
    "burger": "Burger", "american": "American",
    "new_american": "New American", "californian": "Californian",
    "coffee_shop": "Cafe", "coffee": "Cafe",
    "cocktail": "Cocktail Bar", "wine": "Wine Bar",
    "ice_cream": "Dessert", "dessert": "Dessert",
}

def category_for(tags):
    cuisine = (tags.get("cuisine") or "").split(";")[0].strip().lower()
    if cuisine in CUISINE_MAP:
        return CUISINE_MAP[cuisine]
    amenity = tags.get("amenity")
    return AMENITY_FALLBACK.get(amenity, "Other")

def location_for(tags):
    parts = []
    h = tags.get("addr:housenumber")
    s = tags.get("addr:street")
    if h and s: parts.append(f"{h} {s}")
    elif s: parts.append(s)
    city = tags.get("addr:city", "Lancaster")
    state = tags.get("addr:state", "PA")
    parts.append(f"{city}, {state}")
    return ", ".join(parts)

def esc(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"

data = json.load(open("/tmp/lancaster.json"))
seen_names = set()
rows = []
for el in data["elements"]:
    tags = el.get("tags", {})
    name = (tags.get("name") or "").strip()
    if not name:
        continue
    # Dedupe within this batch (some places appear as both node + way)
    key = name.lower()
    if key in seen_names:
        continue
    seen_names.add(key)
    cat = category_for(tags)
    loc = location_for(tags)
    rows.append((str(uuid.uuid4()), name, cat, loc))

print(f"-- {len(rows)} places in Lancaster, PA from OpenStreetMap")
print("insert into restaurants (id, name, cuisine, location, image_url) values")
values = [
    f"('{r[0]}'::uuid, {esc(r[1])}, {esc(r[2])}, {esc(r[3])}, '')"
    for r in rows
]
print(",\n".join(values) + "\non conflict (id) do nothing;")
import sys
print(f"\n-- categories used:", file=sys.stderr)
from collections import Counter
counts = Counter(r[2] for r in rows)
for c, n in counts.most_common():
    print(f"--   {c}: {n}", file=sys.stderr)
