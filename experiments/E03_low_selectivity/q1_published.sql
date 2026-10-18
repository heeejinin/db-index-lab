-- @title 공개 게시글(전체의 약 90%) 집계 — 결과가 대부분인 조회 (PDF 3-1, 3-2)
-- @runs 15
SELECT COUNT(*), SUM(user_id)
FROM posts
WHERE status = 'PUBLISHED';
