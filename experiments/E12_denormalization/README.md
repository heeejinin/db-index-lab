# E12. like_count 반정규화와 정합성

> 자료: 4장 멘티 사례 (posts 100만, likes 1,000만), 면접 Q7 · 4주차 · 약 50분 · **full 규모 권장**

## 배경

피드에 게시글마다 좋아요 수를 보여 줘야 합니다. 방법은 두 가지입니다.

| 방법 | 읽기 | 쓰기 |
|---|---|---|
| 매번 계산 | `COUNT(likes)` 를 요청마다 계산 | 좋아요 INSERT 만 |
| 반정규화 | `posts.like_count` 를 그냥 읽음 | 좋아요 INSERT + **카운터 UPDATE 를 항상 같이** |

자료 4장: *"반정규화는 인덱스의 대체재가 아닙니다. 피드 행을 어디서 빨리 찾는가와 행별 좋아요 집계를 매번 계산할 것인가는 별개의 문제입니다."*

이 실험은 두 부분입니다.

1. **성능**: 최신 피드 20개 / 인기글 TOP 10 을 두 방법으로 비교
2. **정합성**: 트랜잭션, 중복 방지, 버그로 어긋난 카운터 찾기와 복구

## 가설

- 최신 피드 20개 (q1 vs q2): 차이가 클까?:
- 인기글 TOP 10 (q3 vs q4): 차이가 클까?:
- 이유:

## 절차 1: 성능

```bash
make reset-indexes
make sql   F=experiments/E12_denormalization/setup_indexes.sql        # E02, E05 에서 만든 인덱스

make bench Q=experiments/E12_denormalization/q1_feed_count_join.sql L=before_denorm
make bench Q=experiments/E12_denormalization/q3_popular_by_join.sql L=before_denorm

make sql   F=experiments/E12_denormalization/backfill_like_count.sql  # like_count 채우기 + 인기글 인덱스
make bench Q=experiments/E12_denormalization/q2_feed_like_count_column.sql L=after_denorm
make bench Q=experiments/E12_denormalization/q4_popular_by_column.sql      L=after_denorm

make query Q=experiments/E12_denormalization/q3_popular_by_join.sql   # 두 방법의 결과가 같은지 확인
make query Q=experiments/E12_denormalization/q4_popular_by_column.sql

make compare E=E12
```

## 절차 2: 정합성 (자료 4장 「반정규화 시 확인할 정합성 질문」)

```bash
make sql F=experiments/E12_denormalization/verify_like_count.sql    # ① 0건이어야 정상

make sql F=experiments/E12_denormalization/tx_like.sql              # ② 좋아요 + 카운터 +1 (한 트랜잭션)
make sql F=experiments/E12_denormalization/tx_like.sql              # ③ 같은 좋아요 다시 → 어떻게 되나?
make sql F=experiments/E12_denormalization/tx_unlike.sql            # ④ 취소 + 카운터 -1
make sql F=experiments/E12_denormalization/tx_unlike.sql            # ⑤ 이미 취소한 걸 또 취소 → 카운터는?

make sql F=experiments/E12_denormalization/bug_double_increment.sql # ⑥ 버그 재현: 카운터만 +1
make sql F=experiments/E12_denormalization/verify_like_count.sql    # ⑦ 어긋난 게시글이 잡히나?
make sql F=experiments/E12_denormalization/recount_one.sql          # ⑧ 원본 likes 기준으로 복구
make sql F=experiments/E12_denormalization/verify_like_count.sql    # ⑨ 다시 0건?
```

이 실험이 끝나면 posts.like_count 가 채워진 상태로 남습니다. 처음 상태로 돌리려면 `make seed SCALE=...`.

## 기록 (SCALE=____)

| 쿼리 | 라벨 | 훑은 항목 | 서버 p95(ms) |
|---|---|---|---|
| q1 피드 + COUNT | before_denorm | | |
| q2 피드 + like_count | after_denorm | | |
| q3 인기글 집계 | before_denorm | | |
| q4 인기글 컬럼 | after_denorm | | |

backfill(전체 카운터 채우기) 소요 시간: ____

| 단계 | 결과 (게시글 1번 like_count, 에러 여부 등) |
|---|---|
| ② tx_like | |
| ③ tx_like 다시 | |
| ④ tx_unlike | |
| ⑤ tx_unlike 다시 | |
| ⑦ verify (버그 후) | |
| ⑨ verify (복구 후) | |

## 생각해 볼 질문

1. 최신 피드 20개는 반정규화 전에도 충분히 빠를 수 있습니다. 그렇다면 반정규화가 **진짜 필요한 화면**은 어떤 것일까요? (q3 vs q4)
2. ③에서 UNIQUE 인덱스가 없었다면 어떤 일이 생겼을까요? (자료 정합성 질문 1번)
3. ③에서 INSERT 가 실패한 뒤 UPDATE 는 실행됐나요? 애플리케이션 코드(Spring `@Transactional`)에서는 이 상황을 어떻게 처리해야 할까요? (질문 2번)
4. ⑤에서 `ROW_COUNT()` 를 쓴 이유는? 그냥 `like_count - 1` 이면 무슨 문제가 생길까요? (질문 3번)
5. ⑥ 같은 사고는 실무에서 언제 생길 수 있을까요? (재시도, 중복 요청, 배포 중 버그) verify 쿼리를 운영에서 매번 전체로 돌려도 될까요? (질문 4번)
6. 좋아요 수가 몇 초 늦게 반영돼도 되는 서비스라면 어떤 방법을 더 쓸 수 있을까요? (질문 5번, 최종 일관성)
7. 동시에 두 사람이 같은 글에 좋아요를 누르면 `like_count = like_count + 1` 은 안전할까요? → 다음 락·트랜잭션 학습에서 K6 로 확인해 볼 주제

## 결론

- 한 줄 결론:
- 면접 Q7 에 이 실험 결과를 넣어서 답한다면:
