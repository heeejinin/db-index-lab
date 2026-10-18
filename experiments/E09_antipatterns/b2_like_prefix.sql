-- @title [좋은 예] 앞부분이 고정된 LIKE (결과는 b1 과 같음)
-- @param keyword = '게시글 제목 12345 %'
SELECT id, title
FROM posts
WHERE title LIKE :keyword;
