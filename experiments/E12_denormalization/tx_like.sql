-- 좋아요 생성 + 카운터 증가를 "하나의 트랜잭션"으로 (PDF 4장 정합성 질문 2번)
-- 게시글 1번에 회원 99999999 가 좋아요
START TRANSACTION;
INSERT INTO likes (post_id, user_id, created_at) VALUES (1, 99999999, NOW());
UPDATE posts SET like_count = like_count + 1 WHERE id = 1;
COMMIT;

SELECT id, like_count FROM posts WHERE id = 1;
