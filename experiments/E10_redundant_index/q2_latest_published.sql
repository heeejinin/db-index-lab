-- @title 공개 게시글 최신순 20개 (status + 정렬)
-- @runs 20
SELECT id, title, created_at
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT 20;
