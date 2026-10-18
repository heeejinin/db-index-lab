-- 인덱스 5개가 되도록 2개 추가
CREATE INDEX idx_likes_created_at      ON likes (created_at);
CREATE INDEX idx_likes_user_created_at ON likes (user_id, created_at);
