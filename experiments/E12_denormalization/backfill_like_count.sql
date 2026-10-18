-- 원본(likes)을 집계해서 posts.like_count 를 한 번에 채웁니다.
UPDATE posts p
JOIN (SELECT post_id, COUNT(*) AS cnt FROM likes GROUP BY post_id) c ON c.post_id = p.id
SET p.like_count = c.cnt;

-- 인기글 조회용 인덱스
CREATE INDEX idx_posts_status_like_count ON posts (status, like_count, id);
