# E09. 인덱스를 못 타게 만드는 쿼리 모양

> 자료: 3-4 인덱스를 못 타게 만드는 쿼리 모양, 면접 Q5 · 3주차 · 약 60분

인덱스가 **있는데도** 쿼리 모양 때문에 못 쓰는 경우 4가지를, "나쁜 예 / 좋은 예" 쌍으로 비교합니다.
각 쌍은 **결과가 같습니다.** 쿼리 모양만 다릅니다.

| 묶음 | 나쁜 예 | 좋은 예 | 인덱스 |
|---|---|---|---|
| a. 컬럼에 함수 | `DATE(created_at) = '2024-01-15'` | `created_at >= '2024-01-15' AND created_at < '2024-01-16'` | posts(created_at) |
| b. 앞 와일드카드 | `title LIKE '%제목 12345 %'` | `title LIKE '게시글 제목 12345 %'` | posts(title) |
| c. 암묵적 형변환 | `phone = 1000077777` (숫자) | `phone = '01000077777'` (문자열) | users(phone) |
| d. OR | `seller_id = 500 OR category_id = 7` | `UNION ALL` 로 분리 | products(seller_id), products(category_id) |

## 가설

| 묶음 | 나쁜 예 type 예상 | 좋은 예 type 예상 |
|---|---|---|
| a | | |
| b | | |
| c | | |
| d | | |

## 절차

```bash
make reset-indexes

# a. 함수 적용 (인덱스 전 → 후)
make bench Q=experiments/E09_antipatterns/a1_date_function.sql L=before
make sql   F=experiments/E09_antipatterns/index_a_created_at.sql
make bench Q=experiments/E09_antipatterns/a1_date_function.sql L=idx
make bench Q=experiments/E09_antipatterns/a2_date_range.sql    L=idx

# b. LIKE
make sql   F=experiments/E09_antipatterns/index_b_title.sql
make bench Q=experiments/E09_antipatterns/b1_like_contains.sql L=idx
make bench Q=experiments/E09_antipatterns/b2_like_prefix.sql   L=idx

# c. 형변환
make sql   F=experiments/E09_antipatterns/index_c_phone.sql
make bench Q=experiments/E09_antipatterns/c1_phone_number.sql  L=idx
make bench Q=experiments/E09_antipatterns/c2_phone_string.sql  L=idx

# d. OR (인덱스 전 → 후)
make bench Q=experiments/E09_antipatterns/d1_or.sql        L=before
make sql   F=experiments/E09_antipatterns/index_d_seller_and_category.sql
make bench Q=experiments/E09_antipatterns/d1_or.sql        L=idx
make bench Q=experiments/E09_antipatterns/d2_union_all.sql L=idx

make compare E=E09
make reset-indexes
```

## 기록 (SCALE=____)

| 쿼리 | 라벨 | type | possible_keys | key | Extra | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|---|---|---|---|
| a1 DATE() | before | | | | | | |
| a1 DATE() | idx | | | | | | |
| a2 범위 | idx | | | | | | |
| b1 '%..%' | idx | | | | | | |
| b2 '..%' | idx | | | | | | |
| c1 숫자 | idx | | | | | | |
| c2 문자열 | idx | | | | | | |
| d1 OR | before | | | | | | |
| d1 OR | idx | | | | | | |
| d2 UNION ALL | idx | | | | | | |

## 생각해 볼 질문

1. **a**: 인덱스는 `created_at` 값으로 정렬되어 있는데, `DATE(created_at)` 으로 찾으면 왜 그 정렬을 못 쓸까요?
   (MySQL 8 에는 함수 결과에 인덱스를 거는 "함수 인덱스"도 있습니다. 그래도 범위 조건으로 다시 쓰는 것이 먼저인 이유는?)
2. **b**: b1 의 type 이 `index` 로 나올 수 있습니다. `ALL` 과 무엇이 다르고, 왜 그래도 느린가요? ([실행 계획 읽는 법 › type](../../docs/01_실행계획_읽는법.md))
   "제목에 '인덱스'가 들어간 글 검색"이 진짜 요구사항이라면? (자료: FULLTEXT · 검색 엔진 · 요구사항 재검토)
3. **c**: c1 은 `possible_keys` 에 인덱스가 있는데 `key` 가 NULL 입니다. 왜 "후보인데 안 쓴" 걸까요?
   그리고 c1 이 결과를 제대로 찾았는지도 확인해 보세요. `'01000077777'` 과 `1000077777` 은 정말 같은 값일까요?
   Java 에서 `Long phone` 으로 바인딩하면 무슨 일이 생길까요?
4. **d**: OR 인데도 인덱스를 쓰나요? `type = index_merge`, `Using union(...)` 의 뜻은? 그렇다면 자료가 OR 를 조심하라고 한 이유는?
   (조건이 3~4개로 늘어나거나, 한쪽 컬럼에 인덱스가 없으면?)

<details>
<summary>막히면 펼쳐 보기</summary>

- **a**: 인덱스에는 `2024-01-15 10:23:00` 같은 원래 값이 정렬되어 있습니다. `DATE()` 를 씌우면 모든 행의 값을 계산해 봐야 해서 정렬 순서를 이용한 "찾기"가 안 됩니다.
- **b**: B-tree 는 **앞글자부터** 정렬되어 있어서, 앞부분을 모르면 어디서부터 볼지 정할 수 없습니다. 조회 컬럼이 인덱스에 다 있으면 테이블 대신 인덱스 전체를 훑을(`index`) 수는 있습니다.
- **c**: 문자열과 숫자를 비교하면 MySQL 은 **양쪽을 숫자로 바꿔서** 비교합니다. 즉 컬럼 쪽 값마다 변환이 들어가서(a 의 함수와 같은 상황) 인덱스로 찾을 수 없습니다. 숫자로 바꾸면 앞자리 0 이 사라지므로 의도와 다른 행이 맞을 위험도 있습니다.
- **d**: MySQL 은 단순한 OR 는 인덱스 두 개를 따로 읽고 합치는 index_merge 로 처리할 수 있습니다. 항상 되는 것은 아니므로 **EXPLAIN 으로 확인**하고, 안 될 때 UNION ALL 분리를 검토합니다 (자료: "쿼리 분리 여부와 실행 계획 비교").

</details>

## 결론

| 안티패턴 | 내가 확인한 것 | 고치는 방법 |
|---|---|---|
| 함수 적용 | | |
| 앞 와일드카드 | | |
| 형변환 | | |
| OR | | |
