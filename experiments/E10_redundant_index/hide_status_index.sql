-- 바로 지우지 않고 "보이지 않게(INVISIBLE)" 만들어서 영향을 먼저 확인합니다.
-- 옵티마이저는 INVISIBLE 인덱스를 쓰지 않지만, 인덱스 자체는 계속 유지됩니다.
-- 문제가 생기면 show_status_index.sql 로 즉시 되돌릴 수 있습니다 (다시 만드는 것보다 훨씬 빠름).
ALTER TABLE posts ALTER INDEX idx_posts_status INVISIBLE;
SHOW INDEX FROM posts;
