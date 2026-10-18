-- 후보 B: 동등 조건(status) + 정렬 키(created_at) + tie-breaker(id)  (PDF 1-3)
CREATE INDEX idx_posts_status_created_at_id ON posts (status, created_at, id);
