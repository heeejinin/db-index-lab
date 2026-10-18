-- ============================================================
-- 더미 데이터 생성
--   사용: make seed SCALE=small   (기본값, 1분 이내)
--         make seed SCALE=full    (멘토님 PDF 규모, 수 분)
--
-- 주의: 실행하면 기존 데이터와 보조 인덱스를 모두 지우고 새로 만듭니다.
--
-- | 테이블     | small   | full      | 특징                                   |
-- |------------|---------|-----------|----------------------------------------|
-- | users      | 10만    | 100만     | phone은 문자열 '010XXXXXXXX'           |
-- | sellers    | 1천     | 1만       |                                        |
-- | categories | 100     | 200       |                                        |
-- | products   | 20만    | 100만     | 앞번호 판매자에게 상품이 몰림          |
-- | posts      | 10만    | 100만     | PUBLISHED 약 90%, 작성 시각 겹침 있음  |
-- | likes      | 약 100만| 약 1,000만| 인기글 1%에 좋아요 집중                |
--
-- 무작위 값은 RAND() 대신 MD5(번호)로 만들어서
-- 누가 언제 실행해도 "항상 같은 데이터"가 나옵니다. (멘토님과 결과 비교 가능)
-- ============================================================

SOURCE /lab/sql/tools/_procedures.sql

DROP PROCEDURE IF EXISTS seed_all;
DELIMITER //
CREATE PROCEDURE seed_all(IN p_scale VARCHAR(10))
BEGIN
    DECLARE v_users, v_sellers, v_categories, v_products, v_posts INT;
    DECLARE v_normal_max INT DEFAULT 21;   -- 일반 게시글 좋아요 최대 개수
    DECLARE v_hot_max    INT DEFAULT 600;  -- 인기 게시글 좋아요 최대 개수
    DECLARE v_batch      INT DEFAULT 100000;
    DECLARE v_i, v_k, v_max_cnt INT;
    DECLARE v_t0, v_t DATETIME(3);

    IF p_scale = 'small' THEN
        SET v_users = 100000,  v_sellers = 1000,  v_categories = 100, v_products = 200000,  v_posts = 100000;
    ELSEIF p_scale = 'full' THEN
        SET v_users = 1000000, v_sellers = 10000, v_categories = 200, v_products = 1000000, v_posts = 1000000;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SCALE은 small 또는 full 이어야 합니다';
    END IF;

    SET v_t0 = NOW(3);
    SELECT CONCAT('[seed] 시작: SCALE=', p_scale) AS progress;

    -- 0) 초기화: 인덱스가 있으면 데이터 넣는 속도가 느려지므로 먼저 지움
    CALL reset_indexes();
    TRUNCATE TABLE likes;
    TRUNCATE TABLE posts;
    TRUNCATE TABLE products;
    TRUNCATE TABLE categories;
    TRUNCATE TABLE sellers;
    TRUNCATE TABLE users;

    -- 1) 번호표 테이블 seq (1 ~ 1,000,000). 데이터를 "n번째 행"으로 찍어내는 틀
    CREATE TABLE IF NOT EXISTS seq (n INT NOT NULL, PRIMARY KEY (n)) ENGINE = InnoDB;
    IF (SELECT COUNT(*) FROM seq) <> 1000000 THEN
        TRUNCATE TABLE seq;
        INSERT INTO seq (n)
        WITH d AS (SELECT 0 AS v UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                   UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9)
        SELECT a.v + b.v * 10 + c.v * 100 + e.v * 1000 + f.v * 10000 + g.v * 100000 + 1
        FROM d a, d b, d c, d e, d f, d g;
    END IF;

    -- 2) users
    SET v_t = NOW(3), v_i = 0;
    WHILE v_i < v_users DO
        INSERT INTO users (id, email, phone, nickname, status, created_at)
        SELECT n,
               CONCAT('user', n, '@lab.dev'),
               CONCAT('010', LPAD(n, 8, '0')),
               CONCAT('닉네임', n),
               CASE WHEN r1 < 0.95 THEN 'ACTIVE' WHEN r1 < 0.99 THEN 'DORMANT' ELSE 'WITHDRAWN' END,
               TIMESTAMP('2023-01-01') + INTERVAL FLOOR(r2 * 86400 * 1000) SECOND
        FROM (SELECT n,
                     CONV(SUBSTRING(MD5(CONCAT('u0-', n)), 1, 8), 16, 10) / 4294967296 AS r1,
                     CONV(SUBSTRING(MD5(CONCAT('u0-', n)), 9, 8), 16, 10) / 4294967296 AS r2
              FROM seq WHERE n > v_i AND n <= LEAST(v_i + v_batch, v_users)) s;
        SET v_i = v_i + v_batch;
    END WHILE;
    SELECT CONCAT('[seed] users      ', v_users, '건 (', ROUND(TIMESTAMPDIFF(MICROSECOND, v_t, NOW(3)) / 1e6, 1), '초)') AS progress;

    -- 3) sellers, categories
    INSERT INTO sellers (id, name, created_at)
    SELECT n, CONCAT('판매자', n), TIMESTAMP('2022-01-01') + INTERVAL n MINUTE
    FROM seq WHERE n <= v_sellers;

    INSERT INTO categories (id, name)
    SELECT n, CONCAT('카테고리', n)
    FROM seq WHERE n <= v_categories;
    SELECT CONCAT('[seed] sellers    ', v_sellers, '건, categories ', v_categories, '건') AS progress;

    -- 4) products
    --    seller_id = 1 + FLOOR(r^2 * 판매자 수) → 앞번호 판매자일수록 상품이 많음 (대형 판매자 쏠림)
    SET v_t = NOW(3), v_i = 0;
    WHILE v_i < v_products DO
        INSERT INTO products (id, seller_id, category_id, name, price, stock, status, created_at, updated_at)
        SELECT n,
               1 + FLOOR(POW(r1, 2) * v_sellers),
               1 + FLOOR(r2 * v_categories),
               CONCAT('상품 ', n, ' ', ELT(1 + FLOOR(r3 * 6), '티셔츠', '운동화', '키보드', '모니터', '텀블러', '백팩')),
               (1 + FLOOR(r4 * 999)) * 1000,
               FLOOR(r5 * 500),
               CASE WHEN r6 < 0.85 THEN 'ON_SALE' WHEN r6 < 0.97 THEN 'SOLD_OUT' ELSE 'HIDDEN' END,
               TIMESTAMP('2023-01-01') + INTERVAL FLOOR(r7 * 86400 * 1000) SECOND,
               TIMESTAMP('2023-01-01') + INTERVAL FLOOR(r7 * 86400 * 1000) SECOND
        FROM (SELECT n,
                     CONV(SUBSTRING(MD5(CONCAT('p0-', n)), 1, 8), 16, 10) / 4294967296 AS r1,
                     CONV(SUBSTRING(MD5(CONCAT('p0-', n)), 9, 8), 16, 10) / 4294967296 AS r2,
                     CONV(SUBSTRING(MD5(CONCAT('p0-', n)), 17, 8), 16, 10) / 4294967296 AS r3,
                     CONV(SUBSTRING(MD5(CONCAT('p0-', n)), 25, 8), 16, 10) / 4294967296 AS r4,
                     CONV(SUBSTRING(MD5(CONCAT('p1-', n)), 1, 8), 16, 10) / 4294967296 AS r5,
                     CONV(SUBSTRING(MD5(CONCAT('p1-', n)), 9, 8), 16, 10) / 4294967296 AS r6,
                     CONV(SUBSTRING(MD5(CONCAT('p1-', n)), 17, 8), 16, 10) / 4294967296 AS r7
              FROM seq WHERE n > v_i AND n <= LEAST(v_i + v_batch, v_products)) s;
        SET v_i = v_i + v_batch;
    END WHILE;
    SELECT CONCAT('[seed] products   ', v_products, '건 (', ROUND(TIMESTAMPDIFF(MICROSECOND, v_t, NOW(3)) / 1e6, 1), '초)') AS progress;

    -- 5) posts
    --    created_at = 2024-01-01 + (n + 0~2)분 → 대체로 id 순서와 같지만, 같은 시각 글이 자주 생김
    --    (커서 페이지네이션에서 id를 tie-breaker로 넣어야 하는 이유를 재현)
    SET v_t = NOW(3), v_i = 0;
    WHILE v_i < v_posts DO
        INSERT INTO posts (id, user_id, title, content, status, like_count, created_at, updated_at)
        SELECT n,
               1 + FLOOR(POW(r1, 2) * v_users),
               CONCAT('게시글 제목 ', n, ' - ', ELT(1 + FLOOR(r2 * 5), '스프링', 'JPA', '인덱스', 'MySQL', '도커'), ' 이야기'),
               CONCAT('본문 ', n, ' ', REPEAT('lorem ipsum dolor sit amet ', 18)),
               CASE WHEN r3 < 0.90 THEN 'PUBLISHED' WHEN r3 < 0.97 THEN 'DRAFT' ELSE 'DELETED' END,
               0,
               TIMESTAMP('2024-01-01') + INTERVAL (n + FLOOR(r4 * 3)) MINUTE,
               TIMESTAMP('2024-01-01') + INTERVAL (n + FLOOR(r4 * 3)) MINUTE
        FROM (SELECT n,
                     CONV(SUBSTRING(MD5(CONCAT('t0-', n)), 1, 8), 16, 10) / 4294967296 AS r1,
                     CONV(SUBSTRING(MD5(CONCAT('t0-', n)), 9, 8), 16, 10) / 4294967296 AS r2,
                     CONV(SUBSTRING(MD5(CONCAT('t0-', n)), 17, 8), 16, 10) / 4294967296 AS r3,
                     CONV(SUBSTRING(MD5(CONCAT('t0-', n)), 25, 8), 16, 10) / 4294967296 AS r4
              FROM seq WHERE n > v_i AND n <= LEAST(v_i + v_batch, v_posts)) s;
        SET v_i = v_i + v_batch;
    END WHILE;
    SELECT CONCAT('[seed] posts      ', v_posts, '건 (', ROUND(TIMESTAMPDIFF(MICROSECOND, v_t, NOW(3)) / 1e6, 1), '초)') AS progress;

    -- 6) likes
    --    게시글마다 좋아요 개수를 먼저 정함: 1%는 인기글(0~599개), 나머지는 0~20개
    --    (post_id, user_id) 조합은 절대 중복되지 않게 계산 → 나중에 UNIQUE 인덱스를 만들 수 있음
    --    k번째 좋아요를 모든 게시글에 한 바퀴씩 넣기 때문에 같은 게시글의 좋아요가 테이블 곳곳에 흩어짐 (실제 서비스와 비슷)
    SET v_t = NOW(3);
    DROP TABLE IF EXISTS like_targets;
    CREATE TABLE like_targets (post_id BIGINT NOT NULL, cnt INT NOT NULL, PRIMARY KEY (post_id), KEY (cnt)) ENGINE = InnoDB;
    INSERT INTO like_targets (post_id, cnt)
    SELECT n,
           CASE WHEN r1 < 0.01 THEN FLOOR(r2 * v_hot_max)
                ELSE FLOOR(POW(r2, 2) * v_normal_max) END
    FROM (SELECT n,
                 CONV(SUBSTRING(MD5(CONCAT('l0-', n)), 1, 8), 16, 10) / 4294967296 AS r1,
                 CONV(SUBSTRING(MD5(CONCAT('l0-', n)), 9, 8), 16, 10) / 4294967296 AS r2
          FROM seq WHERE n <= v_posts) s;

    SELECT MAX(cnt) INTO v_max_cnt FROM like_targets;
    SET v_k = 0;
    WHILE v_k < v_max_cnt DO
        INSERT INTO likes (post_id, user_id, created_at)
        SELECT post_id,
               MOD(post_id * 7919 + v_k * 104729, v_users) + 1,
               TIMESTAMP('2024-01-01') + INTERVAL (post_id + 3 + v_k * 7 + MOD(CRC32(CONCAT(post_id, '-', v_k)), 60)) MINUTE
        FROM like_targets
        WHERE cnt > v_k;
        IF v_k < v_normal_max AND MOD(v_k, 5) = 4 THEN
            SELECT CONCAT('[seed] likes      ', v_k + 1, '번째 바퀴 완료 (', ROUND(TIMESTAMPDIFF(MICROSECOND, v_t, NOW(3)) / 1e6, 1), '초)') AS progress;
        END IF;
        SET v_k = v_k + 1;
        IF v_k = v_normal_max THEN
            SELECT '[seed] likes      일반 게시글 완료 → 인기 게시글(1%)만 남은 바퀴 계속 (빠름)' AS progress;
        END IF;
    END WHILE;
    DROP TABLE like_targets;
    SELECT CONCAT('[seed] likes      ', (SELECT COUNT(*) FROM likes), '건 (', ROUND(TIMESTAMPDIFF(MICROSECOND, v_t, NOW(3)) / 1e6, 1), '초)') AS progress;

    -- 7) 통계 갱신 (옵티마이저가 정확한 행 수를 알도록)
    ANALYZE TABLE users, sellers, categories, products, posts, likes;

    SELECT CONCAT('[seed] 완료! 총 ', ROUND(TIMESTAMPDIFF(MICROSECOND, v_t0, NOW(3)) / 1e6, 1), '초') AS progress;
END //
DELIMITER ;

CALL seed_all(@scale);
