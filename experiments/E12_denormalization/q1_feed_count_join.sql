-- @title 피드 20개 + 좋아요 수를 매번 COUNT 로 계산 (반정규화 전, PDF 4장)
-- @runs 20
SELECT p.id, p.title, p.created_at, COUNT(l.id) AS like_count
FROM (SELECT id, title, created_at
      FROM posts
      WHERE status = 'PUBLISHED'
      ORDER BY created_at DESC, id DESC
      LIMIT 20) p
LEFT JOIN likes l ON l.post_id = p.id
GROUP BY p.id, p.title, p.created_at
ORDER BY p.created_at DESC, p.id DESC;
