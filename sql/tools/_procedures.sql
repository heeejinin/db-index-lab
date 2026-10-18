-- ============================================================
-- 실습 도구 프로시저 (seed.sql / reset_indexes.sql 이 불러서 사용)
-- ============================================================

-- ------------------------------------------------------------
-- reset_indexes(): 실습 테이블을 "PRIMARY KEY만 있는 상태"로 되돌림
--   1) 외래 키 삭제   2) PRIMARY 를 제외한 모든 인덱스 삭제
-- 실험이 끝날 때마다 실행해서 다음 실험이 영향을 받지 않게 합니다.
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS reset_indexes;
DELIMITER //
CREATE PROCEDURE reset_indexes()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_table VARCHAR(64);
    DECLARE v_name  VARCHAR(64);
    DECLARE v_count INT DEFAULT 0;

    DECLARE fk_cur CURSOR FOR
        SELECT TABLE_NAME, CONSTRAINT_NAME
        FROM information_schema.TABLE_CONSTRAINTS
        WHERE TABLE_SCHEMA = DATABASE()
          AND CONSTRAINT_TYPE = 'FOREIGN KEY';

    DECLARE idx_cur CURSOR FOR
        SELECT DISTINCT TABLE_NAME, INDEX_NAME
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND INDEX_NAME <> 'PRIMARY'
          AND TABLE_NAME IN ('users', 'sellers', 'categories', 'products', 'posts', 'likes');

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- 1) 외래 키 먼저 삭제 (외래 키가 쓰는 인덱스는 외래 키보다 먼저 지울 수 없음)
    OPEN fk_cur;
    fk_loop: LOOP
        FETCH fk_cur INTO v_table, v_name;
        IF done THEN LEAVE fk_loop; END IF;
        SET @ddl = CONCAT('ALTER TABLE `', v_table, '` DROP FOREIGN KEY `', v_name, '`');
        PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
        SET v_count = v_count + 1;
    END LOOP;
    CLOSE fk_cur;

    -- 2) 보조 인덱스 삭제
    SET done = 0;
    OPEN idx_cur;
    idx_loop: LOOP
        FETCH idx_cur INTO v_table, v_name;
        IF done THEN LEAVE idx_loop; END IF;
        SET @ddl = CONCAT('ALTER TABLE `', v_table, '` DROP INDEX `', v_name, '`');
        PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
        SET v_count = v_count + 1;
    END LOOP;
    CLOSE idx_cur;

    SELECT CONCAT('외래 키·보조 인덱스 ', v_count, '개 삭제 → PRIMARY KEY만 남은 상태') AS reset_indexes;
END //
DELIMITER ;
