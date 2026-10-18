-- @title 커서 방식 (PDF 1-4 그대로: 행 생성자 비교)
-- 기본값은 SCALE=small, offset=50000 위치의 커서입니다. full 이면 find_cursor 로 다시 구하세요.
-- @param cursorCreatedAt = '2024-01-31 21:41:00'
-- @param cursorId = 44500
-- @runs 20
SELECT id, title, created_at
FROM posts
WHERE status = 'PUBLISHED'
  AND (created_at, id) < (:cursorCreatedAt, :cursorId)
ORDER BY created_at DESC, id DESC
LIMIT 21;
