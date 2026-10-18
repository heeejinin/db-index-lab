-- 각 조건 컬럼에 단일 인덱스 두 개
CREATE INDEX idx_products_seller   ON products (seller_id);
CREATE INDEX idx_products_category ON products (category_id);
