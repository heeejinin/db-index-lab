# E07. 커버링 인덱스와 SELECT *

> 자료: 1-5 커버링 인덱스가 가능한 좁은 목록 조회, 3-4 표의 SELECT * · 2주차 · 약 30분

## 배경

인덱스 `(status, created_at, id)` 하나로, **조회 컬럼만 다른** 세 쿼리를 비교합니다.

| 쿼리 | SELECT | 인덱스만으로 끝나나? |
|---|---|---|
| q1 | `id, created_at` | 전부 인덱스에 있음 → 커버링 |
| q2 | `id, title, created_at` | title 은 테이블에 가야 함 |
| q3 | `*` (content 약 500바이트 포함) | 전부 테이블에 가야 함 |

[기초개념 6단계](../../docs/00_기초개념.md): 커버링이면 "두 번째 찾기(PK 로 테이블 가기)"를 건너뜁니다.

차이가 잘 보이도록 기본값은 `LIMIT 1000` 입니다. 자료처럼 `LIMIT 20` 으로도 비교해 보세요.

## 가설

- q1 의 Extra 에 무엇이 나올까?:
- q1 → q2 → q3 시간 순서와 대략적인 차이:
- LIMIT 20 이면 차이가 어떻게 될까?:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E07_covering/q1_covering.sql L=before

make sql   F=experiments/E07_covering/index_status_created_at_id.sql
make bench Q=experiments/E07_covering/q1_covering.sql    L=idx
make bench Q=experiments/E07_covering/q2_with_title.sql  L=idx
make bench Q=experiments/E07_covering/q3_select_star.sql L=idx

make bench Q=experiments/E07_covering/q1_covering.sql    L=idx_limit20 P='size=20'
make bench Q=experiments/E07_covering/q3_select_star.sql L=idx_limit20 P='size=20'

make compare E=E07
make reset-indexes
```

## 기록 (SCALE=____)

| 쿼리 | 라벨 | Extra | 훑은 항목 | 서버 p95(ms) | 클라이언트 p95(ms) |
|---|---|---|---|---|---|
| q1 | before | | | | |
| q1 | idx | | | | |
| q2 | idx | | | | |
| q3 | idx | | | | |
| q1 | idx_limit20 | | | | |
| q3 | idx_limit20 | | | | |

## 생각해 볼 질문

1. q1~q3 의 "훑은 항목" 수는 같은데 시간은 다릅니다. 이 숫자에 안 잡히는 일은 무엇일까요?
2. q3 에서 "서버 실행"과 "클라이언트" 시간 차이가 q1 보다 큰 이유는?
3. LIMIT 20 에서는 차이가 거의 없을 수도 있습니다. 그렇다면 커버링 인덱스는 언제 의미가 클까요?
4. 목록 API 를 커버링으로 만들려고 인덱스에 title, content 까지 넣으면 어떤 문제가 생길까요? (자료 1-5 마지막 문단)

## 결론

- 한 줄 결론:
- 목록 API 응답 DTO 에 대한 내 기준:
