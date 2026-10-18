-- 현재 테이블 상태: 행 수, 크기, 인덱스 목록
-- 사용: make status
SET SESSION information_schema_stats_expiry = 0;

-- 인덱스를 만들거나 지운 직후에는 크기 통계가 옛날 값일 수 있어서 먼저 갱신합니다.
ANALYZE TABLE users, sellers, categories, products, posts, likes;

SELECT TABLE_NAME                                   AS `table`,
       FORMAT(TABLE_ROWS, 0)                        AS `rows(추정)`,
       ROUND(DATA_LENGTH  / 1024 / 1024, 1)         AS `data_pk_mb`,
       ROUND(INDEX_LENGTH / 1024 / 1024, 1)         AS `secondary_index_mb`
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('users', 'sellers', 'categories', 'products', 'posts', 'likes')
ORDER BY FIELD(TABLE_NAME, 'users', 'sellers', 'categories', 'products', 'posts', 'likes');

SELECT TABLE_NAME                                                        AS `table`,
       INDEX_NAME                                                        AS `index_name`,
       GROUP_CONCAT(COALESCE(COLUMN_NAME, EXPRESSION) ORDER BY SEQ_IN_INDEX SEPARATOR ', ') AS `columns`,
       IF(NON_UNIQUE = 0, 'UNIQUE', '')                                  AS `uniq`,
       IF(IS_VISIBLE = 'YES', '', 'INVISIBLE')                           AS `visible`
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('users', 'sellers', 'categories', 'products', 'posts', 'likes')
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE, IS_VISIBLE
ORDER BY FIELD(TABLE_NAME, 'users', 'sellers', 'categories', 'products', 'posts', 'likes'), INDEX_NAME = 'PRIMARY' DESC, INDEX_NAME;
