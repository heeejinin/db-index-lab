-- @title q1 과 같은 조회에서 인덱스를 "쓰지 말라"고 지시하면? (IGNORE INDEX → 풀스캔)
-- 인덱스가 있는 상태에서 "인덱스 사용 vs 풀스캔"을 같은 조건으로 비교하기 위한 쿼리입니다.
-- @runs 15
SELECT COUNT(*), SUM(user_id)
FROM posts IGNORE INDEX (idx_posts_status)
WHERE status = 'PUBLISHED';
