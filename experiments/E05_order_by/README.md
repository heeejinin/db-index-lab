# E05. 최신순 정렬과 filesort

> 자료: 1-3 정렬과 작은 결과 집합 · 2주차 · 약 30분

## 배경

```sql
SELECT id, title, created_at FROM posts
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

게시판 첫 화면 쿼리입니다. 20개만 필요한데, 인덱스가 없으면 **전체를 읽고 → 정렬하고 → 앞의 20개**를 고릅니다 (`Using filesort`).

인덱스는 이미 정렬된 목록이라서, 정렬된 순서로 **앞에서(최신순이면 뒤에서) 20개만 읽고 멈출 수** 있습니다.

- 후보 A: `(created_at)` 정렬 컬럼만
- 후보 B: `(status, created_at, id)` 동등 조건 + 정렬 키 + tie-breaker (자료 1-3)

`id` 를 정렬에 넣은 이유: 같은 시각(분 단위)에 쓰인 글이 많아서, created_at 만으로는 순서가 매번 달라질 수 있기 때문입니다 ([데이터 설명](../../docs/03_데이터_설명.md)).

## 가설

- 인덱스 전 Extra 에 무엇이 나올까?:
- A 와 B 중 무엇이 빠를까? 차이가 클까?:
- 드문 값(DRAFT 7%)을 찾으면 A 와 B 의 차이가 어떻게 변할까?:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E05_order_by/q1_latest_published.sql L=before
make bench Q=experiments/E05_order_by/q2_latest_draft.sql     L=before

make sql   F=experiments/E05_order_by/index_a_created_at.sql
make bench Q=experiments/E05_order_by/q1_latest_published.sql L=idx_a
make bench Q=experiments/E05_order_by/q2_latest_draft.sql     L=idx_a

make reset-indexes
make sql   F=experiments/E05_order_by/index_b_status_created_at_id.sql
make bench Q=experiments/E05_order_by/q1_latest_published.sql L=idx_b
make bench Q=experiments/E05_order_by/q2_latest_draft.sql     L=idx_b

make compare E=E05
make reset-indexes
```

## 기록 (SCALE=____)

| 쿼리 | 라벨 | type | key | Extra | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|---|---|---|
| q1 PUBLISHED | before | | | | | |
| q2 DRAFT | before | | | | | |
| q1 PUBLISHED | idx_a | | | | | |
| q2 DRAFT | idx_a | | | | | |
| q1 PUBLISHED | idx_b | | | | | |
| q2 DRAFT | idx_b | | | | | |

## 생각해 볼 질문

1. `Using filesort` 가 사라졌나요? 대신 무엇이 나왔나요? (`Backward index scan`)
2. 인덱스는 오름차순인데 DESC 정렬을 어떻게 처리했나요? (자료 1-3 의 "역방향 B-tree 스캔")
3. 인덱스 A 로 q2(DRAFT) 를 실행하면 왜 훑은 항목이 20보다 많아지나요? 만약 status 가 0.01% 인 값이라면?
4. 인덱스 A 의 type 이 `index` 인데도 빠른 이유는? (LIMIT 과 같이 생각해 보세요)
5. 이 데이터에서 A 도 충분히 빠르다면, 굳이 B 를 고르는 이유는 무엇일까요? (E08 커서와도 연결됩니다)

## 결론

- 한 줄 결론:
