-- 복구: 원본 likes 를 기준으로 특정 게시글의 카운터를 다시 계산
UPDATE posts
SET like_count = (SELECT COUNT(*) FROM likes WHERE post_id = 1)
WHERE id = 1;
SELECT id, like_count FROM posts WHERE id = 1;
