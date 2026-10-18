-- 인덱스 3개가 되도록 2개 추가
CREATE UNIQUE INDEX uk_likes_post_user ON likes (post_id, user_id);
CREATE INDEX idx_likes_user_id ON likes (user_id);
