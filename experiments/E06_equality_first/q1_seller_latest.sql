-- @title 판매자별 판매 중 상품 최신순 + 커서 (PDF 9-1)
-- @param sellerId = 500
-- @param cursorCreatedAt = '2025-06-01 00:00:00'
SELECT id, name, price, created_at
FROM products
WHERE seller_id = :sellerId
  AND status = 'ON_SALE'
  AND created_at < :cursorCreatedAt
ORDER BY created_at DESC, id DESC
LIMIT 20;
