-- @title 특정 게시글의 좋아요 목록 (PDF 1-2)
-- @param postId = 12342
-- @runs 20
SELECT p.id, p.title, l.user_id, l.created_at
FROM posts p
JOIN likes l ON l.post_id = p.id
WHERE p.id = :postId;
