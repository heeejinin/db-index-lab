-- [더 해보기] 외래 키를 만들면 InnoDB가 인덱스를 자동으로 만드는지 확인
-- 주의: likes 가 크면 외래 키 검증에 시간이 걸립니다 (small 기준 수 초).
-- 끝나면 make reset-indexes 로 외래 키와 인덱스를 함께 지우세요.
SHOW INDEX FROM likes;
ALTER TABLE likes ADD CONSTRAINT fk_likes_post FOREIGN KEY (post_id) REFERENCES posts (id);
SHOW INDEX FROM likes;
