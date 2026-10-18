-- 왼쪽 접두가 겹치는 두 인덱스를 일부러 만듭니다 (PDF 3-5)
CREATE INDEX idx_posts_status                ON posts (status);
CREATE INDEX idx_posts_status_created_at_id  ON posts (status, created_at, id);
