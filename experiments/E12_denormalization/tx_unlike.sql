-- 좋아요 취소 + 카운터 감소. 실제로 지워진 행이 있을 때만 감소시켜야 합니다.
-- (이미 취소된 좋아요를 또 취소하면 지워진 행이 0개 → 카운터도 그대로)
START TRANSACTION;
DELETE FROM likes WHERE post_id = 1 AND user_id = 99999999;
SET @deleted = ROW_COUNT();
UPDATE posts SET like_count = like_count - @deleted WHERE id = 1;
COMMIT;

SELECT @deleted AS deleted_rows, id, like_count FROM posts WHERE id = 1;
