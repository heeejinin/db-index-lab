-- @title 좋아요 많은 공개 글 TOP 10 — likes 전체를 집계 (반정규화 전)
-- @runs 5
-- @warmup 1
SELECT p.id, p.title, c.cnt AS like_count
FROM (SELECT post_id, COUNT(*) AS cnt
      FROM likes
      GROUP BY post_id
      ORDER BY cnt DESC
      LIMIT 50) c
JOIN posts p ON p.id = c.post_id
WHERE p.status = 'PUBLISHED'
ORDER BY c.cnt DESC, p.id DESC
LIMIT 10;
