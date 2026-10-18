-- PRIMARY KEY 외의 모든 인덱스와 외래 키를 삭제해서 "인덱스 전" 상태로 되돌립니다.
-- 사용: make reset-indexes
SOURCE /lab/sql/tools/_procedures.sql
CALL reset_indexes();
