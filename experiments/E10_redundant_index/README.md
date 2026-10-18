# E10. 중복 인덱스 찾기와 안전한 제거

> 자료: 3-5 중복·접두 인덱스, 면접 Q6 · 3주차 · 약 30분

## 배경

```
INDEX idx_posts_status                (status)
INDEX idx_posts_status_created_at_id  (status, created_at, id)
```

`(status)` 는 `(status, created_at, id)` 의 **왼쪽 접두**와 같습니다. 큰 인덱스가 작은 인덱스의 일을 대신할 수 있다면 작은 쪽은 공간과 쓰기 비용만 차지합니다.

자료 3-5: *"단, 바로 삭제하면 안 됩니다. ... 검증 환경에서 제거 효과를 측정해야 합니다."*
MySQL 8 의 **INVISIBLE 인덱스**는 이걸 위한 기능입니다. 인덱스를 지우지 않고 옵티마이저에게만 "없는 셈 쳐"라고 합니다. 문제가 생기면 즉시 VISIBLE 로 되돌릴 수 있습니다.

## 가설

- 두 인덱스가 다 있을 때, `status` 만 쓰는 q1 은 어느 인덱스를 고를까?:
- `idx_posts_status` 를 숨기면 q1 이 느려질까?:

## 절차

```bash
make reset-indexes
make sql   F=experiments/E10_redundant_index/setup_indexes.sql

make bench Q=experiments/E10_redundant_index/q1_deleted_count.sql    L=both
make bench Q=experiments/E10_redundant_index/q2_latest_published.sql L=both

make sql   F=experiments/E10_redundant_index/check_redundant.sql     # 중복 후보, 미사용 인덱스, 크기

make sql   F=experiments/E10_redundant_index/hide_status_index.sql   # INVISIBLE
make bench Q=experiments/E10_redundant_index/q1_deleted_count.sql    L=status_invisible
make bench Q=experiments/E10_redundant_index/q2_latest_published.sql L=status_invisible

# 영향이 없으면 삭제, 문제가 있으면 show_status_index.sql 로 되돌리기
make sql   F=experiments/E10_redundant_index/drop_status_index.sql

make compare E=E10
make reset-indexes
```

## 기록 (SCALE=____)

| 쿼리 | 라벨 | key | Extra | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|---|---|
| q1 | both | | | | |
| q2 | both | | | | |
| q1 | status_invisible | | | | |
| q2 | status_invisible | | | | |

`sys.schema_redundant_indexes` 결과:

인덱스 크기: idx_posts_status ____MB / idx_posts_status_created_at_id ____MB

## 생각해 볼 질문

1. `sys.schema_redundant_indexes` 가 알려준 내용과 `sql_drop_index` 열은 무엇인가요? 이 결과만 믿고 운영에서 바로 실행해도 될까요?
2. INVISIBLE 로 바꾼 뒤 q1 의 시간과 훑은 항목이 달라졌나요?
3. 자료 3-5 의 "전체 쿼리 목록, 인덱스 사용 현황, 배포 위험"을 실무에서는 각각 어떻게 확인할 수 있을까요?
   (`sys.schema_unused_indexes`, 슬로우 쿼리 로그, `performance_schema.table_io_waits_summary_by_index_usage`)
4. 인덱스를 지우는 것과 다시 만드는 것, 어느 쪽이 더 위험하고 오래 걸릴까요? INVISIBLE 이 왜 유용한가요?

## 결론

- 한 줄 결론:
- 중복 인덱스를 지우는 내 절차:
