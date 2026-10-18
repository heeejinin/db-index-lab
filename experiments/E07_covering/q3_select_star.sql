-- @title SELECT * (큰 본문 content 까지)
-- @param size = 1000
-- @runs 20
SELECT *
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT :size;
