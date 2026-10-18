-- @title 카테고리로만 찾기 → 인덱스 (category_id, price)의 왼쪽 컬럼 사용
-- @param categoryId = 7
SELECT id, name, price
FROM products
WHERE category_id = :categoryId;
