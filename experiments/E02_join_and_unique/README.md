# E02. 조인 키 인덱스와 UNIQUE 로 무결성까지

> 자료: 1-2 조인과 외래 키 탐색, 한 장 요약 표(중복되면 안 되는 값) · 1주차 · 약 40분

## 배경

```sql
SELECT p.id, p.title, l.user_id, l.created_at
FROM posts p JOIN likes l ON l.post_id = p.id
WHERE p.id = :postId;
```

게시글은 PK 로 바로 찾지만(`const`), **likes 쪽에서 post_id 가 같은 행**을 찾으려면 인덱스가 필요합니다.
small 은 likes 가 약 94만 건, full 은 약 947만 건입니다.

좋아요는 "한 사람이 한 게시글에 한 번만"이어야 합니다. 이 규칙을 애플리케이션 코드만 믿지 않고 **DB 가 막게** 하는 것이 UNIQUE 인덱스입니다.
이메일도 마찬가지입니다.

## 가설

- 인덱스 전 likes 쪽 type: ____ / 훑을 행 수: ____
- `idx_likes_post_id` 후 보통 글(12개)과 인기 글(599개)의 차이:
- `uk_likes_post_user (post_id, user_id)` 만 있어도 q1 이 빠를까? 이유:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E02_join_and_unique/q1_post_likes.sql L=before
make bench Q=experiments/E02_join_and_unique/q1_post_likes.sql L=before_hot P='postId=21087'
make bench Q=experiments/E02_join_and_unique/q2_user_by_email.sql L=before

# 조인 키 인덱스
make sql   F=experiments/E02_join_and_unique/index_a_likes_post.sql
make bench Q=experiments/E02_join_and_unique/q1_post_likes.sql L=idx_post
make bench Q=experiments/E02_join_and_unique/q1_post_likes.sql L=idx_post_hot P='postId=21087'

# 유니크 인덱스 (중복 확인 → 생성)
make reset-indexes
make sql   F=experiments/E02_join_and_unique/index_b_likes_unique.sql
make bench Q=experiments/E02_join_and_unique/q1_post_likes.sql L=uk_post_user
make sql   F=experiments/E02_join_and_unique/try_duplicate_like.sql     # 일부러 에러가 나야 정상!

# 이메일 UNIQUE
make sql   F=experiments/E02_join_and_unique/index_c_users_email.sql
make bench Q=experiments/E02_join_and_unique/q2_user_by_email.sql L=uk_email

make compare E=E02
make reset-indexes
```

`try_duplicate_like.sql` 은 `ERROR 1062 ... Duplicate entry` 와 함께 `make: *** Error 1` 이 나와야 정상입니다.

## 기록 (SCALE=____)

| 라벨 | likes/users type | key | 훑은 항목 | 결과 행 | 서버 p95(ms) |
|---|---|---|---|---|---|
| before | | | | | |
| before_hot | | | | | |
| idx_post | | | | | |
| idx_post_hot | | | | | |
| uk_post_user | | | | | |
| q2 before | | | | | |
| q2 uk_email | | | | | |

중복 INSERT 결과:

## 생각해 볼 질문

1. 인덱스 전에는 좋아요가 12개인 글과 599개인 글의 시간이 왜 비슷한가요?
2. 인덱스 후에는 왜 차이가 나나요? 인기 글이 많은 서비스라면 무엇을 더 고민해야 할까요?
3. `(post_id, user_id)` UNIQUE 인덱스가 있으면 `(post_id)` 단일 인덱스는 따로 필요할까요? ([기초개념 7단계](../../docs/00_기초개념.md))
4. q2 의 type 이 `const` 가 된 이유는?
5. `CREATE UNIQUE INDEX` 전에 중복 확인 쿼리를 먼저 돌린 이유는? 운영 DB에 이미 중복이 있었다면 어떻게 해야 할까요?

## 더 해보기: 외래 키를 만들면 인덱스가 생길까?

```bash
make sql F=experiments/E02_join_and_unique/extra_fk_auto_index.sql
make reset-indexes     # 외래 키와 자동 생성 인덱스를 함께 정리
```

외래 키 추가 전후 `SHOW INDEX` 를 비교해 보세요. 이 레포의 테이블에 외래 키를 일부러 선언하지 않은 이유이기도 합니다.
(full 규모에서는 외래 키 검증에 시간이 좀 걸립니다)

## 결론

- 한 줄 결론:
- UNIQUE 인덱스의 두 가지 역할:
