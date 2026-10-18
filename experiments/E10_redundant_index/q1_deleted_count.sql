-- @title 삭제된 글 개수 (status 만 사용하는 쿼리)
-- @runs 20
SELECT COUNT(*)
FROM posts
WHERE status = 'DELETED';
