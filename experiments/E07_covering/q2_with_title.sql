-- @title 인덱스에 없는 title 하나 추가
-- @param size = 1000
-- @runs 20
SELECT id, title, created_at
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT :size;
