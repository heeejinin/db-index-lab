-- 후보 A: 등치 조건 먼저 → 범위·정렬 키 → tie-breaker
CREATE INDEX idx_products_seller_status_created_id ON products (seller_id, status, created_at, id);
