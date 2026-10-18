# E01. 풀스캔 vs 인덱스, 단일 vs 복합 인덱스

> 자료: 1-1 선택도가 있는 필터 조회 · 1주차 · 약 40분

## 배경

```sql
SELECT id, name, price FROM products WHERE seller_id = :sellerId AND status = 'ON_SALE';
```

판매자 상세 페이지에서 "판매 중인 상품"을 보여 주는 쿼리입니다.
인덱스가 없으면 products 전체를 읽고 하나씩 비교합니다 ([기초개념 2단계](../../docs/00_기초개념.md)).

인덱스 후보는 두 가지입니다.

- A: `(seller_id)` 하나만
- B: `(seller_id, status)` 복합 (자료 1-1 의 인덱스)

결과는 같은데 무엇이 다를까요?

## 가설 (측정 전에 적기)

- 인덱스 전 type: ____ / 훑을 행 수: ____
- 인덱스 A 후 훑을 행 수: ____
- 인덱스 B 후 훑을 행 수: ____
- A와 B의 차이가 커지는 경우는?:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=before
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=before_seller1 P='sellerId=1'

make sql   F=experiments/E01_single_filter/index_a_seller.sql
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=idx_a
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=idx_a_seller1 P='sellerId=1'

make reset-indexes
make sql   F=experiments/E01_single_filter/index_b_seller_status.sql
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=idx_b
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=idx_b_seller1 P='sellerId=1'

make compare E=E01
make reset-indexes
```

- `sellerId=500` 은 상품이 적은 보통 판매자, `sellerId=1` 은 상품이 아주 많은 대형 판매자입니다.

## 기록 (SCALE=____)

| 라벨 | type | key | key_len | 훑은 항목 | 결과 행 | 서버 p95(ms) |
|---|---|---|---|---|---|---|
| before | | | | | | |
| before_seller1 | | | | | | |
| idx_a | | | | | | |
| idx_a_seller1 | | | | | | |
| idx_b | | | | | | |
| idx_b_seller1 | | | | | | |

## 생각해 볼 질문

1. 인덱스 전에는 판매자 500과 1의 시간이 비슷한가요? 왜 그럴까요?
2. 인덱스 A에서 "훑은 항목"과 "결과 행" 차이는 무엇 때문에 생기나요? (EXPLAIN 의 `filtered`, `Extra` 를 보세요)
3. key_len 이 A와 B에서 왜 다른가요? ([실행 계획 읽는 법 › key_len](../../docs/01_실행계획_읽는법.md))
4. 이 데이터에서 B가 A보다 확실히 나은가요? 인덱스 크기와 쓰기 비용까지 생각하면 어느 쪽을 고를까요?

<details>
<summary>막히면 펼쳐 보기</summary>

- 인덱스가 없으면 판매자와 상관없이 **테이블 전체**를 읽기 때문에 시간이 비슷합니다.
- A는 seller_id 로 찾은 뒤 테이블에서 status 를 확인하고 버립니다 (`Using where`). 판매 중이 아닌 상품만큼 헛걸음을 합니다.
- B는 인덱스 안에서 status 까지 걸러서 결과 행 수 = 훑은 항목 수가 됩니다.
- ON_SALE 이 85%라서 헛걸음은 15% 정도입니다. 그래서 둘의 시간 차이는 크지 않을 수 있습니다. 차이가 작다면 그것도 중요한 결론입니다.

</details>

## 결론

- 한 줄 결론:
- 실무에서 이 쿼리라면 고를 인덱스와 이유:
