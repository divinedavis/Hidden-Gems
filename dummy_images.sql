-- ============================================================
-- Hidden Gems — restaurant image backfill
-- Run this in the Supabase SQL Editor
-- ============================================================
-- Assigns a cuisine-appropriate Unsplash photo to every restaurant
-- that doesn't already have an image_url.

update restaurants set image_url = case
  when cuisine ilike '%italian seafood%'                                then 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=800&q=80'
  when cuisine ilike '%italian%'                                        then 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800&q=80'
  when cuisine ilike '%mexican%'                                        then 'https://images.unsplash.com/photo-1565299585323-38174c4a6471?w=800&q=80'
  when cuisine ilike '%bbq%' or cuisine ilike '%barbecue%'              then 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800&q=80'
  when cuisine ilike '%korean%'                                         then 'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=800&q=80'
  when cuisine ilike '%japanese%' or cuisine ilike '%sushi%'            then 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800&q=80'
  when cuisine ilike '%thai%'                                           then 'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=800&q=80'
  when cuisine ilike '%french%'                                         then 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80'
  when cuisine ilike '%seafood%' or cuisine ilike '%oyster%'            then 'https://images.unsplash.com/photo-1535140728325-a4d3707eee94?w=800&q=80'
  when cuisine ilike '%middle eastern%' or cuisine ilike '%israeli%'    then 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&q=80'
  when cuisine ilike '%vegetarian%'                                     then 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80'
  when cuisine ilike '%californian%'                                    then 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80'
  when cuisine ilike '%pacific northwest%'                              then 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800&q=80'
  when cuisine ilike '%american%'                                       then 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800&q=80'
  else                                                                       'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80'
end
where image_url is null or image_url = '';
