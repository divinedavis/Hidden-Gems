-- ============================================================
-- Hidden Gems — comment replies (one level of nesting)
-- Run once in the Supabase SQL Editor if not already applied.
-- ============================================================

-- Self-reference on comments. A NULL parent_comment_id means the
-- row is a top-level comment; a non-null value means it's a reply
-- to another comment on the same post.
alter table comments
  add column if not exists parent_comment_id uuid
    references comments(id) on delete cascade;

-- Index for fast lookup of replies by parent.
create index if not exists comments_parent_comment_id_idx
  on comments (parent_comment_id);
