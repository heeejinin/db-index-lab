-- 이미 있는 (post_id, user_id) 조합을 한 번 더 넣어 봅니다.
-- uk_likes_post_user 가 있으면 "ERROR 1062 Duplicate entry" 로 막혀야 정상입니다.
-- (인덱스가 없으면 그냥 들어가 버립니다 → 그 경우 아래 DELETE 로 지워 주세요)
INSERT INTO likes (post_id, user_id, created_at)
SELECT post_id, user_id, NOW() FROM likes ORDER BY id LIMIT 1;

-- 유니크 인덱스 없이 들어가 버렸다면 정리용:
-- DELETE FROM likes WHERE id = (SELECT id FROM (SELECT MAX(id) AS id FROM likes) t);
