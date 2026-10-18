-- @title 판매자별 판매 중 상품 목록 (PDF 1-1)
-- @param sellerId = 500
SELECT id, name, price
FROM products
WHERE seller_id = :sellerId
  AND status = 'ON_SALE';
