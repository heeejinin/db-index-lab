# E01_single_filter / q1_seller_on_sale [before]

판매자별 판매 중 상품 목록 (PDF 1-1)

- 측정 시각: 2026-10-18 23:54:42
- MySQL 8.4.11, buffer pool 1152MB
- 워밍업 5회, 측정 30회, 모드 read
- 파라미터: `{'sellerId': 500}`
- 결과 행 수: 112

## 실행한 SQL
```sql
SELECT id, name, price
FROM products
WHERE seller_id = 500
  AND status = 'ON_SALE'
```

## 시간 (ms)
|  | avg | p50 | p95 | p99 | min | max |
|---|---|---|---|---|---|---|
| 서버 실행 | 38.21 | 36.46 | 45.52 | 68.15 | 34.97 | 68.15 |
| 클라이언트 | 38.75 | 36.99 | 46.15 | 69.00 | 35.40 | 69.00 |

## 서버 통계 (마지막 1회, performance_schema)
| rows_examined | rows_sent | sort_rows | no_index_used | select_scan | created_tmp_tables |
|---|---|---|---|---|---|
| 200000 | 112 | 0 | 1 | 1 | 0 |

## 엔진이 훑은 행·인덱스 항목 (합계 200,003)
| 인덱스로 위치 찾기 | 인덱스 순서대로 다음 행 | 인덱스 역순으로 이전 행 | 인덱스 첫 항목 | 인덱스 마지막 항목 | 테이블 순차 스캔(풀스캔) | 위치로 행 다시 읽기(정렬 후 등) | 인덱스 안에서 검사 후 버림(ICP) |
|---|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 1 | 0 | 200,001 | 0 | 0 |

## EXPLAIN
| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | products | NULL | ALL | NULL | NULL | NULL | NULL | 198869 | 1.0 | Using where |

## EXPLAIN ANALYZE
```
-> Filter: ((products.`status` = 'ON_SALE') and (products.seller_id = 500))  (cost=20200 rows=1989) (actual time=0.837..47.3 rows=112 loops=1)
    -> Table scan on products  (cost=20200 rows=198869) (actual time=0.0613..29.3 rows=200000 loops=1)

```

## 관련 테이블 인덱스
- products (약 198,869행): PRIMARY(id)
