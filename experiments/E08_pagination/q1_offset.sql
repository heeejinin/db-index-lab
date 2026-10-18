-- @title OFFSET 방식: 앞의 :offset 개를 읽고 버린 뒤 20개 (PDF 1-4, 3-4)
-- @param offset = 50000
-- @runs 20
SELECT id, title, created_at
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET :offset;
