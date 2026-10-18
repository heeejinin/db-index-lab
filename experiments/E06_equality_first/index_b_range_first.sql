-- 후보 B: 범위·정렬 키를 맨 앞에 (PDF 9-1의 "반대" 예시)
CREATE INDEX idx_products_created_seller_status_id ON products (created_at, seller_id, status, id);
