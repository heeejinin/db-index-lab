-- @title [좋은 예] 날짜 범위로 재작성 (결과는 a1 과 같음)
-- @param day = '2024-01-15'
SELECT id, title, created_at
FROM posts
WHERE created_at >= :day
  AND created_at <  :day + INTERVAL 1 DAY;
