# E06. 등치 조건 먼저 vs 범위 조건 먼저

> 자료: 9장 등치 조건 선행과 실행 계획, 면접 Q2 · 2주차 · 약 40분

## 배경

```sql
SELECT id, name, price, created_at FROM products
WHERE seller_id = :sellerId          -- 등치(=)
  AND status = 'ON_SALE'             -- 등치(=)
  AND created_at < :cursorCreatedAt  -- 범위(<), 커서
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

같은 네 컬럼으로 **순서만 다른** 두 인덱스를 비교합니다.

| 후보 | 컬럼 순서 | 자료 9-1 |
|---|---|---|
| A | `(seller_id, status, created_at, id)` | 등치 조건 먼저 → 범위·정렬 → tie-breaker |
| B | `(created_at, seller_id, status, id)` | 범위·정렬 키를 맨 앞에 ("반대로" 예시) |

전화번호부로 치면, A 는 "판매자별로 나눈 뒤 날짜순", B 는 "날짜순으로 전부 섞여 있고 그 안에 판매자"입니다.

## 가설

- A 와 B 모두 인덱스를 쓸까?:
- 둘 중 훑는 항목이 더 많은 쪽과 이유:
- 대형 판매자(sellerId=1)로 바꾸면 B 의 성능은 좋아질까 나빠질까?:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E06_equality_first/q1_seller_latest.sql L=before

make sql   F=experiments/E06_equality_first/index_a_equality_first.sql
make bench Q=experiments/E06_equality_first/q1_seller_latest.sql L=idx_a
make bench Q=experiments/E06_equality_first/q1_seller_latest.sql L=idx_a_seller1 P='sellerId=1'

make reset-indexes
make sql   F=experiments/E06_equality_first/index_b_range_first.sql
make bench Q=experiments/E06_equality_first/q1_seller_latest.sql L=idx_b
make bench Q=experiments/E06_equality_first/q1_seller_latest.sql L=idx_b_seller1 P='sellerId=1'

make compare E=E06
make reset-indexes
```

## 기록 (SCALE=____)

| 라벨 | type | key | key_len | Extra | rows_examined | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|---|---|---|---|
| before | | | | | | | |
| idx_a | | | | | | | |
| idx_a_seller1 | | | | | | | |
| idx_b | | | | | | | |
| idx_b_seller1 | | | | | | | |

## 생각해 볼 질문

1. A 와 B 모두 type 이 `range` 이고 `rows_examined` 도 20으로 같게 나올 수 있습니다. 그런데 시간과 "훑은 항목"은 어떤가요?
   → `rows_examined` 만 보면 속을 수 있는 이유 ([측정 원칙 › 읽은 행 수](../../docs/02_측정_원칙.md))
2. key_len 은 A 와 B 에서 각각 몇이고, 무엇을 뜻하나요? (B 는 인덱스의 몇 번째 컬럼까지 "찾기"에 썼나요?)
3. B 에서 대형 판매자가 오히려 빠른 이유는? (날짜순으로 거꾸로 읽다가 20개를 얼마나 빨리 채우는지)
4. "등치 조건을 앞에 둔다"가 **절대 공식이 아닌** 경우를 자료 9-2 에서 하나 골라, 이 레포로 실험할 방법을 생각해 보세요.

## 결론

- 한 줄 결론:
- 면접 Q2 에 이 실험 결과를 넣어서 답한다면:
