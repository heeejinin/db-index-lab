-- @title 피드 20개 + 반정규화한 posts.like_count 읽기 (반정규화 후)
-- @runs 20
SELECT id, title, created_at, like_count
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT 20;
