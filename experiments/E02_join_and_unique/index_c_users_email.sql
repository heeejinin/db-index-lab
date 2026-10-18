-- 이메일은 중복되면 안 되는 값 → 조회 성능 + 무결성을 같이 얻는 UNIQUE 인덱스
CREATE UNIQUE INDEX uk_users_email ON users (email);
