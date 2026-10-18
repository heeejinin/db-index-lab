-- @title [나쁜 예] 앞에 % 가 붙은 LIKE
-- @param keyword = '%제목 12345 %'
SELECT id, title
FROM posts
WHERE title LIKE :keyword;
