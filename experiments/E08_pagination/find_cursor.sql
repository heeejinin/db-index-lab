-- @title OFFSET 위치에 해당하는 커서 값(created_at, id) 찾기 — q2, q3 의 파라미터로 사용
-- @param offset = 50000
SELECT created_at AS cursorCreatedAt, id AS cursorId
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT 1 OFFSET :offset;
