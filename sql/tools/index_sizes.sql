-- 인덱스별 크기 (MB). 인덱스도 디스크와 메모리를 차지한다는 것을 숫자로 확인합니다.
-- 사용: make sql F=sql/tools/index_sizes.sql
-- ANALYZE TABLE 로 통계를 먼저 갱신해야 정확합니다.
ANALYZE TABLE users, products, posts, likes;

SELECT table_name                                                    AS `table`,
       index_name                                                    AS `index_name`,
       ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 1)       AS `size_mb`
FROM mysql.innodb_index_stats
WHERE database_name = DATABASE()
  AND stat_name = 'size'
  AND table_name IN ('users', 'sellers', 'categories', 'products', 'posts', 'likes')
ORDER BY table_name, index_name = 'PRIMARY' DESC, index_name;
