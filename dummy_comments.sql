-- ============================================================
-- Hidden Gems — comment seed data
-- Run this in the Supabase SQL Editor
-- ============================================================
-- Creates 3 comments per post on 25 random posts (~75 total),
-- each from a random user with a random pre-written comment.

insert into comments (post_id, user_id, text, created_at)
select
  p.id,
  (select id from users order by random() limit 1),
  (array[
    'Looks amazing — adding to my list!',
    'Went here last weekend, totally agree.',
    'This is the best take on this spot I have seen.',
    'Been wanting to try this forever.',
    'Date night locked in.',
    'Seriously underrated.',
    'Omg yes, love this place.',
    'Take me here please.',
    'The vibes alone are worth it.',
    'Must try — making a reservation now.',
    'Can confirm, incredible food.',
    'This just made my week.',
    'One of my favorite spots in the city.',
    'The menu is unreal, you can''t go wrong.',
    'Saving this for my birthday dinner.',
    'Best recommendation I have seen all month.'
  ])[floor(random() * 16 + 1)::int],
  now() - (random() * interval '20 days')
from (select id from posts order by random() limit 25) p
cross join generate_series(1, 3);
