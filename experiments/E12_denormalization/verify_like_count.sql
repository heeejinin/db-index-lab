-- 정합성 검증: 원본 likes 로 다시 센 값과 posts.like_count 가 다른 게시글 (0건이어야 정상)
SELECT p.id, p.like_count AS stored_count, COALESCE(c.cnt, 0) AS actual_count
FROM posts p
LEFT JOIN (SELECT post_id, COUNT(*) AS cnt FROM likes GROUP BY post_id) c ON c.post_id = p.id
WHERE p.like_count <> COALESCE(c.cnt, 0)
LIMIT 20;
