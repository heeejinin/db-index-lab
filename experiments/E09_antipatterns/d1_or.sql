-- @title 서로 다른 컬럼을 OR 로 연결한 검색
-- @param sellerId = 500
-- @param categoryId = 7
SELECT id, name
FROM products
WHERE seller_id = :sellerId
   OR category_id = :categoryId;
