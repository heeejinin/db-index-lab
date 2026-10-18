-- @title 커서 방식 (조건을 풀어서 쓴 버전)
-- @param cursorCreatedAt = '2024-01-31 21:41:00'
-- @param cursorId = 44500
-- @runs 20
SELECT id, title, created_at
FROM posts
WHERE status = 'PUBLISHED'
  AND (created_at < :cursorCreatedAt
       OR (created_at = :cursorCreatedAt AND id < :cursorId))
ORDER BY created_at DESC, id DESC
LIMIT 21;
