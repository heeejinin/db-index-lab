-- 버그 재현: 좋아요는 그대로인데 카운터만 한 번 더 올라감 (재시도·중복 요청에서 흔한 사고)
UPDATE posts SET like_count = like_count + 1 WHERE id = 1;
SELECT id, like_count FROM posts WHERE id = 1;
