-- @title [더 해보기] q3 에서 인덱스에 있는 컬럼만 조회하면? (skip scan 관찰)
-- @param minPrice = 100000
-- @param maxPrice = 101000
SELECT id, category_id, price
FROM products
WHERE price BETWEEN :minPrice AND :maxPrice;
