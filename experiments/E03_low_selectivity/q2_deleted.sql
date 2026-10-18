-- @title 삭제된 게시글(전체의 약 3%) 집계 — 결과가 일부인 조회
-- @runs 15
SELECT COUNT(*), SUM(user_id)
FROM posts
WHERE status = 'DELETED';
