-- @title [더 해보기] 임시저장 글(약 7%) 최신순 20개 — 드문 값이면 인덱스 A/B 차이가 커질까?
-- @runs 20
SELECT id, title, created_at
FROM posts
WHERE status = 'DRAFT'
ORDER BY created_at DESC, id DESC
LIMIT 20;
