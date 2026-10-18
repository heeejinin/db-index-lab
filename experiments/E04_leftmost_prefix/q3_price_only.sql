-- @title 가격 범위로만 찾기 → 왼쪽 컬럼(category_id) 없이 두 번째 컬럼만 사용
-- @param minPrice = 100000
-- @param maxPrice = 101000
SELECT id, name, price
FROM products
WHERE price BETWEEN :minPrice AND :maxPrice;
