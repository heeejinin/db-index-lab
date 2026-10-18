-- @title [나쁜 예] 문자열 컬럼(phone)을 숫자로 비교 → 암묵적 형변환
-- @param phone = 1000077777
SELECT id, nickname, phone
FROM users
WHERE phone = :phone;
