-- @title [좋은 예] 컬럼 타입과 같은 문자열로 비교
-- @param phone = '01000077777'
SELECT id, nickname, phone
FROM users
WHERE phone = :phone;
