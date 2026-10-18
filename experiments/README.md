# 실험 목록

각 폴더에는 다음이 들어 있습니다.

| 파일 | 역할 |
|---|---|
| `README.md` | 배경 설명, 가설 칸, 실행 명령어, 기록 표, 생각해 볼 질문 |
| `q*.sql` | 측정할 쿼리 (`make bench` / `make explain` / `make query` 로 실행) |
| `index_*.sql`, 기타 `.sql` | 인덱스 추가 등 (`make sql` 로 실행) |

| 주차 | 실험 | 주제 | 자료 |
|---|---|---|---|
| 1 | [E01](E01_single_filter) | 풀스캔 vs 인덱스, 단일 vs 복합 | 1-1 |
| 1 | [E02](E02_join_and_unique) | 조인 키 인덱스, UNIQUE 로 무결성까지 | 1-2 |
| 1 | [E03](E03_low_selectivity) | 값 종류가 적은 컬럼의 인덱스 | 3-1, 3-2 |
| 2 | [E04](E04_leftmost_prefix) | 복합 인덱스는 왼쪽부터 | 2 |
| 2 | [E05](E05_order_by) | 정렬과 filesort | 1-3 |
| 2 | [E06](E06_equality_first) | 등치 조건 먼저 vs 범위 조건 먼저 | 9 |
| 2 | [E07](E07_covering) | 커버링 인덱스와 SELECT * | 1-5 |
| 3 | [E08](E08_pagination) | OFFSET vs 커서 페이지네이션 | 1-4 |
| 3 | [E09](E09_antipatterns) | 인덱스를 못 타게 만드는 쿼리 모양 | 3-4 |
| 3 | [E10](E10_redundant_index) | 중복 인덱스 찾기와 안전한 제거 | 3-5 |
| 4 | [E11](E11_write_cost) | 인덱스가 늘면 INSERT 는 얼마나 느려지나 | 3-3 |
| 4 | [E12](E12_denormalization) | like_count 반정규화와 정합성 | 4 |

## 쿼리 파일 형식

```sql
-- @title  판매자별 판매 중 상품
-- @param  sellerId = 500          ← 기본값. make bench ... P='sellerId=1' 로 바꿀 수 있음
-- @param  status   = 'ON_SALE'    ← 문자열은 작은따옴표
-- @runs   30                      ← (선택) 측정 횟수
-- @warmup 5                       ← (선택) 워밍업 횟수
-- @mode   write                   ← (선택) INSERT/UPDATE/DELETE 를 매번 ROLLBACK
SELECT id, name, price FROM products WHERE seller_id = :sellerId AND status = :status;
```

새 실험을 만들 때는 `experiments/E13_나의실험/` 폴더를 만들고 이 형식으로 쿼리를 넣은 뒤, [templates/실험기록.md](../templates/실험기록.md) 를 README 로 복사해서 쓰면 됩니다.
