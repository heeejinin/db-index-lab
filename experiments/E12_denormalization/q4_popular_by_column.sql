-- @title 좋아요 많은 공개 글 TOP 10 — like_count 컬럼 + 인덱스 (반정규화 후)
-- @runs 20
SELECT id, title, like_count
FROM posts
WHERE status = 'PUBLISHED'
ORDER BY like_count DESC, id DESC
LIMIT 10;
