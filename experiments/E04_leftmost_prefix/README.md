# E04. 복합 인덱스는 왼쪽부터

> 자료: 2장 왼쪽부터 사용되는 원칙 · 2주차 · 약 30분

## 배경

인덱스 `(category_id, price)` 하나를 만들고, 조건이 다른 세 쿼리를 비교합니다.

| 쿼리 | 조건 | 인덱스의 어느 부분? |
|---|---|---|
| q1 | `category_id = 7` | 왼쪽 컬럼 |
| q2 | `category_id = 7 AND price BETWEEN 100000 AND 150000` | 왼쪽 + 두 번째 |
| q3 | `price BETWEEN 100000 AND 101000` | 두 번째만 (왼쪽 없음) |

[기초개념 7단계](../../docs/00_기초개념.md)의 전화번호부를 떠올려 보세요. "성 없이 이름만"으로 찾는 것이 q3 입니다.

## 가설

- q1, q2, q3 각각 인덱스를 쓸까? type 은?:
- q2 의 key_len 이 q1 보다 클까?:

## 절차

```bash
make reset-indexes
make bench Q=experiments/E04_leftmost_prefix/q1_category.sql       L=before
make bench Q=experiments/E04_leftmost_prefix/q2_category_price.sql L=before
make bench Q=experiments/E04_leftmost_prefix/q3_price_only.sql     L=before

make sql   F=experiments/E04_leftmost_prefix/index_category_price.sql
make bench Q=experiments/E04_leftmost_prefix/q1_category.sql       L=idx
make bench Q=experiments/E04_leftmost_prefix/q2_category_price.sql L=idx
make bench Q=experiments/E04_leftmost_prefix/q3_price_only.sql     L=idx

make compare E=E04
```

## 기록 (SCALE=____)

| 쿼리 | 라벨 | type | key | key_len | Extra | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|---|---|---|---|
| q1 | before | | | | | | |
| q2 | before | | | | | | |
| q3 | before | | | | | | |
| q1 | idx | | | | | | |
| q2 | idx | | | | | | |
| q3 | idx | | | | | | |

## 생각해 볼 질문

1. q1(key_len 8)과 q2(key_len 12)의 차이는 무엇을 뜻하나요?
2. q3 는 인덱스를 썼나요? 썼다면/안 썼다면 왜일까요?
3. 가격 범위 검색(q3)이 자주 쓰이는 핵심 쿼리라면 어떤 인덱스를 추가로 고민해야 할까요?

## 더 해보기: skip scan

```bash
make bench Q=experiments/E04_leftmost_prefix/q4_price_only_covering.sql L=idx
make reset-indexes
```

q3 와 조건은 같지만 **인덱스에 있는 컬럼만** 조회합니다. `Extra` 에 무엇이 나오나요?
MySQL 8.0.13 부터 있는 "skip scan"은 앞 컬럼(category_id) 값마다 건너뛰며 인덱스를 씁니다.
왼쪽 접두 원칙의 **예외**처럼 보이지만, 조건이 까다롭습니다 (조회 컬럼이 인덱스 안에 있어야 하는 등). 그래서 "b 만으로 찾는 쿼리에 이 인덱스를 주 인덱스로 기대하면 안 된다"(자료 2장)는 원칙은 그대로입니다.

## 결론

- 한 줄 결론:
