-- 이 실험의 출발점: E02, E05 에서 만든 인덱스
CREATE UNIQUE INDEX uk_likes_post_user ON likes (post_id, user_id);
CREATE INDEX idx_posts_status_created_at_id ON posts (status, created_at, id);
