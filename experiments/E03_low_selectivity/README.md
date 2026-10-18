# E03. 값 종류가 적은 컬럼의 인덱스

> 자료: 3-1 결과 대부분을 반환하는 조회, 3-2 값 종류가 적은 컬럼의 단독 인덱스, 면접 Q3 · 1주차 · 약 30분

## 배경

posts.status 는 값이 3개뿐입니다.

| status | 비율 |
|---|---|
| PUBLISHED | 약 90% |
| DRAFT | 약 7% |
| DELETED | 약 3% |

같은 `idx_posts_status` 인덱스라도 **어떤 값을 찾느냐에 따라** 효과가 완전히 다를 수 있습니다.

```sql
SELECT COUNT(*), SUM(user_id) FROM posts WHERE status = 'PUBLISHED';   -- q1: 90%
SELECT COUNT(*), SUM(user_id) FROM posts WHERE status = 'DELETED';     -- q2: 3%
```

`SUM(user_id)` 를 넣은 이유: user_id 는 인덱스에 없어서 **행마다 테이블에 다시 가야** 합니다 ([기초개념 5단계](../../docs/00_기초개념.md) 두 번 찾기).

## 가설

- q1 (90%) 에 인덱스를 쓰면 빨라질까, 느려질까? 이유:
- q2 (3%) 는?:
- 옵티마이저는 q1 에서 인덱스를 쓸까?:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E03_low_selectivity/q1_published.sql L=before
make bench Q=experiments/E03_low_selectivity/q2_deleted.sql   L=before

make sql   F=experiments/E03_low_selectivity/index_status.sql
make bench Q=experiments/E03_low_selectivity/q1_published.sql L=idx_status
make bench Q=experiments/E03_low_selectivity/q2_deleted.sql   L=idx_status
make bench Q=experiments/E03_low_selectivity/q3_published_ignore_index.sql L=idx_status_ignored   # 인덱스가 있지만 쓰지 말라고 지시

make compare E=E03
make reset-indexes
```

## 기록 (SCALE=____)

| 쿼리 | 라벨 | type | key | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|---|---|
| q1 PUBLISHED | before | | | | |
| q2 DELETED | before | | | | |
| q1 PUBLISHED | idx_status | | | | |
| q2 DELETED | idx_status | | | | |
| q3 PUBLISHED | idx_status_ignored | | | | |

## 생각해 볼 질문

1. q1 에서 옵티마이저는 인덱스를 골랐나요? 그 선택이 실제로 더 빨랐나요? (`idx_status` vs `idx_status_ignored`)
2. 훑은 항목 수는 인덱스를 쓴 쪽이 더 적은데, 시간은 어떤가요? "읽는 행 수"만으로 설명이 안 되는 부분은 무엇일까요?
   (힌트: 순서대로 쭉 읽기 vs PK 로 여기저기 찾아가기)
3. q2 는 왜 결과가 다르게 나왔나요?
4. 자료 3-1 의 "인덱스가 있는데도 사용하지 않는다는 것이 곧 오류는 아닙니다"를, 이 실험 결과로 다시 설명해 보세요.

<details>
<summary>막히면 펼쳐 보기</summary>

- 인덱스로 찾으면 행마다 **PK 로 테이블에 다시 가는 랜덤 접근**이 생깁니다. 결과가 90%면 거의 모든 행에 대해 이 일을 합니다.
- 풀스캔은 페이지를 **순서대로** 쭉 읽어서 한 페이지에 있는 여러 행을 한 번에 처리합니다.
- 그래서 결과 비율이 높으면 "훑은 항목"이 적어도 오히려 느릴 수 있습니다. 옵티마이저의 추정이 항상 맞지는 않다는 것도 이 실험에서 볼 수 있는 포인트입니다.
- 이 경우 실무에서는 status 단독 인덱스보다 `(status, created_at, id)` 처럼 **실제 쿼리 패턴과 결합한** 인덱스를 먼저 봅니다 (E05, 자료 3-2).

</details>

## 결론

- 한 줄 결론:
- "값 종류가 적은 컬럼 인덱스"에 대한 내 기준:
