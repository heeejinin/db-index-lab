-- 1) 유니크 인덱스를 만들기 전에, 이미 중복된 데이터가 있는지 먼저 확인합니다.
--    중복이 하나라도 있으면 CREATE UNIQUE INDEX 는 실패합니다.
SELECT post_id, user_id, COUNT(*) AS dup
FROM likes
GROUP BY post_id, user_id
HAVING COUNT(*) > 1
LIMIT 10;

-- 2) 중복 좋아요를 DB 차원에서 막는 유니크 인덱스 (PDF 1-2)
--    post_id 가 맨 앞에 있으므로 "post_id 로 찾기"에도 그대로 쓸 수 있습니다.
CREATE UNIQUE INDEX uk_likes_post_user ON likes (post_id, user_id);
