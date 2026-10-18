-- 후보 B: seller_id + status (PDF 1-1의 인덱스)
CREATE INDEX idx_products_seller_status ON products (seller_id, status);
