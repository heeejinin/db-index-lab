-- @title OR 를 UNION ALL 로 나눈 버전 (두 번째 쿼리에서 첫 번째 결과를 빼서 중복 제거)
-- @param sellerId = 500
-- @param categoryId = 7
SELECT id, name FROM products WHERE seller_id = :sellerId
UNION ALL
SELECT id, name FROM products WHERE category_id = :categoryId AND seller_id <> :sellerId;
