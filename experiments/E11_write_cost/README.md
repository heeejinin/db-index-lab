# E11. 인덱스가 늘면 INSERT 는 얼마나 느려지나

> 자료: 3-3 쓰기 핫패스, 면접 Q6 · 4주차 · 약 40분

## 배경

인덱스는 읽기를 빠르게 하지만, **INSERT 할 때마다 인덱스 B-tree 도 같이 고쳐야** 합니다 ([기초개념 10단계](../../docs/00_기초개념.md)).
좋아요처럼 쓰기가 몰리는 테이블에서, 인덱스 개수를 0 → 1 → 3 → 5 개로 늘리며 **같은 INSERT** 를 측정합니다.

```sql
-- 좋아요 1,000건 INSERT. 측정 도구가 매번 ROLLBACK 하므로 데이터는 그대로 유지됩니다 (-- @mode write)
INSERT INTO likes (post_id, user_id, created_at)
SELECT 1 + MOD(n * 104729, (SELECT MAX(id) FROM posts)), 100000000 + n, ...
FROM seq WHERE n <= 1000;
```

| 단계 | likes 의 보조 인덱스 |
|---|---|
| idx0 | 없음 (PK 만) |
| idx1 | `(post_id)` |
| idx3 | + `UNIQUE (post_id, user_id)`, `(user_id)` |
| idx5 | + `(created_at)`, `(user_id, created_at)` |

## 가설

- 인덱스 0개 → 5개일 때 INSERT 시간은 몇 배 정도?:
- 인덱스 1개 추가될 때마다 비슷하게 늘어날까?:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E11_write_cost/q1_insert_1000_likes.sql L=idx0

make sql   F=experiments/E11_write_cost/index_step1.sql
make bench Q=experiments/E11_write_cost/q1_insert_1000_likes.sql L=idx1

make sql   F=experiments/E11_write_cost/index_step2.sql
make bench Q=experiments/E11_write_cost/q1_insert_1000_likes.sql L=idx3

make sql   F=experiments/E11_write_cost/index_step3.sql
make bench Q=experiments/E11_write_cost/q1_insert_1000_likes.sql L=idx5

make sql   F=sql/tools/index_sizes.sql        # 인덱스별 크기
make status                                   # 테이블 대비 보조 인덱스 총 크기

make compare E=E11
make reset-indexes
```

full 규모에서는 인덱스 생성(`make sql`) 자체에 시간이 걸립니다. 각 단계의 생성 시간도 적어 두세요 (자료 6장: 대용량 테이블 DDL 의 영향).

## 기록 (SCALE=____)

| 단계 | 보조 인덱스 수 | 인덱스 생성 시간 | INSERT 1,000건 서버 p50(ms) | p95(ms) | 보조 인덱스 총 크기(MB) |
|---|---|---|---|---|---|
| idx0 | 0 | - | | | |
| idx1 | 1 | | | | |
| idx3 | 3 | | | | |
| idx5 | 5 | | | | |

likes 테이블(데이터+PK) 크기: ____MB

## 생각해 볼 질문

1. 인덱스 수와 INSERT 시간이 정비례하나요? 특히 0 → 1 구간은 어떤가요?
2. 이 INSERT 는 post_id 를 기존 게시글 곳곳에 흩어서 넣습니다. 인덱스 B-tree 의 **여러 페이지**를 건드려야 하는 이유와, 그게 비용에 미치는 영향은?
3. 보조 인덱스 5개의 총 크기는 테이블 데이터 대비 몇 % 인가요? 버퍼 풀(1GB)을 나눠 쓴다는 점에서 어떤 영향이 있을까요?
4. 이 측정은 "혼자서 1,000건"입니다. 실제 서비스에서 좋아요가 동시에 몰리면 무엇이 더 나빠질 수 있을까요? (자료 3-3: 락 경합, 페이지 분할, 복제 비용)

## 더 해보기

- `q1` 을 복사해서 post_id 를 `9000000 + n` (항상 맨 끝에 추가)으로 바꾼 버전을 만들어 비교해 보세요. 인덱스의 "어디에" 넣느냐가 비용을 바꿀까요?
- `P='rows=100'`, `P='rows=10000'` 으로 바꿔 행 수에 따른 변화도 볼 수 있습니다.

## 결론

- 한 줄 결론:
- 쓰기가 많은 테이블에 인덱스를 추가할 때 내 기준:
