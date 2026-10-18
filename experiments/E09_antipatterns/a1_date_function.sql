-- @title [나쁜 예] 컬럼에 함수 적용: DATE(created_at)
-- @param day = '2024-01-15'
SELECT id, title, created_at
FROM posts
WHERE DATE(created_at) = :day;
