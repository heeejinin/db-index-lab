-- @title 인덱스에 있는 컬럼만 조회 (커버링 인덱스, PDF 1-5)
-- @param size = 1000
-- @runs 20
SELECT id, created_at
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT :size;
