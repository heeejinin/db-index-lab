-- @title 카테고리 + 가격 범위 → 왼쪽부터 두 컬럼 모두 사용 (PDF 2장 표: 카테고리별 가격 범위 검색)
-- @param categoryId = 7
-- @param minPrice = 100000
-- @param maxPrice = 150000
SELECT id, name, price
FROM products
WHERE category_id = :categoryId
  AND price BETWEEN :minPrice AND :maxPrice;
