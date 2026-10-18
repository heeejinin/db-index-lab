-- @title 이메일로 회원 찾기 (로그인·중복 가입 확인)
-- @param email = 'user77777@lab.dev'
SELECT id, nickname
FROM users
WHERE email = :email;
