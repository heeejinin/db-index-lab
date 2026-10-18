-- 1) MySQL sys 스키마가 알려주는 "중복 인덱스" 후보
SELECT table_name, redundant_index_name, redundant_index_columns,
       dominant_index_name, dominant_index_columns, sql_drop_index
FROM sys.schema_redundant_indexes
WHERE table_schema = DATABASE();

-- 2) 서버가 켜진 뒤 한 번도 쓰이지 않은 인덱스 (실험 쿼리를 몇 번 돌린 뒤에 보세요)
SELECT * FROM sys.schema_unused_indexes WHERE object_schema = DATABASE();

-- 3) 인덱스별 크기
ANALYZE TABLE posts;
SELECT index_name, ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 1) AS size_mb
FROM mysql.innodb_index_stats
WHERE database_name = DATABASE() AND table_name = 'posts' AND stat_name = 'size';
