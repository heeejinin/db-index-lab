# E08. OFFSET vs 커서 페이지네이션

> 자료: 1-4 커서 기반 페이지네이션, 3-4 표의 큰 OFFSET, 면접 Q4 · 3주차 · 약 50분

## 배경

무한 스크롤에서 "다음 20개"를 가져오는 두 가지 방법입니다.

```sql
-- q1 OFFSET: 앞의 50,000개를 읽고 버린 뒤 20개
... ORDER BY created_at DESC, id DESC LIMIT 20 OFFSET 50000;

-- q2 커서: "마지막으로 본 글보다 이전" 부터 21개 (자료 1-4 그대로)
... AND (created_at, id) < (:cursorCreatedAt, :cursorId)
    ORDER BY created_at DESC, id DESC LIMIT 21;

-- q3 커서: 같은 조건을 풀어서 쓴 버전
... AND (created_at < :cursorCreatedAt
         OR (created_at = :cursorCreatedAt AND id < :cursorId))
    ORDER BY created_at DESC, id DESC LIMIT 21;
```

- 21개를 읽는 이유: 20개를 보여 주고, 21번째가 있으면 "다음 페이지 있음" (자료 1-4 size + 1)
- q2 와 q3 는 **수학적으로 같은 조건**입니다. 실행 계획도 같을까요?

인덱스는 세 쿼리 모두 `(status, created_at, id)` 를 씁니다.

## 가설

- OFFSET 이 0 → 50,000 으로 커지면 훑는 항목은?:
- 커서 방식(q2)은 위치가 깊어도 일정할까?:
- q2 와 q3 의 실행 계획이 같을까?:

## 절차

```bash
make reset-indexes
make sql   F=experiments/E08_pagination/index_status_created_at_id.sql

# 1) OFFSET 깊이별
make bench Q=experiments/E08_pagination/q1_offset.sql L=offset0     P='offset=0'
make bench Q=experiments/E08_pagination/q1_offset.sql L=offset5000  P='offset=5000'
make bench Q=experiments/E08_pagination/q1_offset.sql L=offset50000 P='offset=50000'

# 2) 같은 위치(50,000번째)의 커서 값 구하기
make query Q=experiments/E08_pagination/find_cursor.sql P='offset=50000'
#   → 나온 cursorCreatedAt, cursorId 를 아래 P 에 넣기 (small 이면 기본값과 같음)

# 3) 커서 두 가지
make bench Q=experiments/E08_pagination/q2_cursor_row.sql L=cursor_row P="cursorCreatedAt='2024-01-31 21:41:00' cursorId=44500"
make bench Q=experiments/E08_pagination/q3_cursor_or.sql  L=cursor_or  P="cursorCreatedAt='2024-01-31 21:41:00' cursorId=44500"

make compare E=E08
make reset-indexes
```

**full** 규모라면 `offset=500000` 까지 해 보고, `find_cursor` 로 그 위치의 커서를 다시 구하세요.

## 기록 (SCALE=____)

| 쿼리 | 라벨 | type | key_len | Extra | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|---|---|---|
| q1 | offset0 | | | | | |
| q1 | offset5000 | | | | | |
| q1 | offset50000 | | | | | |
| q2 | cursor_row | | | | | |
| q3 | cursor_or | | | | | |

## 생각해 볼 질문

1. OFFSET 은 인덱스를 쓰는데도 깊어질수록 왜 느려지나요? (자료 3-4 "인덱스를 사용해도 앞 행을 버려야 함")
2. q2 와 q3 의 type, key_len, 훑은 항목을 비교해 보세요. **같은 뜻의 SQL 인데 왜 다를까요?**
3. key_len 이 82 인 것과 95 인 것은 각각 인덱스의 어디까지 "찾기"에 썼다는 뜻인가요?
4. 이 결과를 보고 자료 1-4 의 SQL 을 실무 코드에 그대로 써도 될까요? JPA/QueryDSL 로 작성한다면 어떤 형태로 쓰겠어요?
5. 커서 방식의 단점(자료 1-4: 45페이지로 바로 이동 불가 등)은 무엇이고, 어떤 화면에는 OFFSET 이 여전히 맞을까요?

<details>
<summary>막히면 펼쳐 보기 (직접 측정한 뒤에 보세요)</summary>

- MySQL 은 `(a, b) < (x, y)` 같은 **행 생성자 비교**를 인덱스 범위 탐색에 잘 쓰지 못하는 경우가 있습니다. 그러면 인덱스의 앞부분(status)만 쓰고, 최신 글부터 커서 위치까지 **하나씩 읽으면서** 조건을 검사하게 되어 OFFSET 과 비슷한 일을 하게 됩니다.
- 조건을 `a < x OR (a = x AND b < y)` 로 풀어 쓰면 범위 탐색(range)으로 커서 위치에 바로 찾아갑니다.
- MySQL 공식 문서의 "Row Constructor Expression Optimization" 항목에서도 이 내용을 다룹니다. 직접 찾아 읽어 보세요.
- "자료에 나온 SQL 도 내 환경에서 실행 계획으로 검증한다"는 것 자체가 이 4주의 핵심입니다. 멘토링 때 이야기해 볼 만한 발견입니다.

</details>

## 결론

- 한 줄 결론:
- 실무에서 쓸 커서 쿼리 형태:
