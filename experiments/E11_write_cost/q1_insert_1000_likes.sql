-- @title 좋아요 1,000건 INSERT (매번 ROLLBACK 해서 데이터는 그대로) (PDF 3-3)
-- user_id 는 실제 회원 번호보다 큰 값을 써서 (post_id, user_id) 중복이 생기지 않게 함
-- post_id 는 기존 게시글 곳곳에 흩어지게 함 → 인덱스의 여러 페이지를 건드림 (실제와 비슷)
-- @mode write
-- @param rows = 1000
-- @runs 20
INSERT INTO likes (post_id, user_id, created_at)
SELECT 1 + MOD(n * 104729, (SELECT MAX(id) FROM posts)),
       100000000 + n,
       TIMESTAMP('2024-06-01') + INTERVAL MOD(n * 7919, 500000) MINUTE
FROM seq
WHERE n <= :rows;
