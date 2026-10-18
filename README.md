# DB 인덱스 실습 환경 (db-index-lab)

> "조회가 느리니 인덱스를 추가하자"라는 감 대신, **실행 계획과 측정값으로 인덱스를 판단하는 연습**을 하기 위한 실습 레포입니다.
> 멘토링 자료 「DB 인덱스 설계: 사용 기준·안티패턴·조회 성능 면접 준비」의 내용을 **직접 재현하고 측정**하도록 구성했습니다.

- **DB**: MySQL 8.4 (InnoDB), Docker로 실행
- **데이터**: posts 100만 · likes 약 1,000만 건까지 (자료의 멘티 사례와 같은 규모)
- **측정**: 쿼리를 반복 실행해 평균·p95·p99, 읽은 행 수, `EXPLAIN`, `EXPLAIN ANALYZE`를 파일로 저장하고 전후 비교
- **기간**: 4주, 주 1회 (→ [4주 계획](docs/PLAN.md))

---

## 1. 준비물

| 필요한 것 | 확인 명령어 | 없으면 |
|---|---|---|
| Docker Desktop | `docker compose version` | [Docker Desktop 설치](https://www.docker.com/products/docker-desktop/) (Apple Silicon 맥은 Apple Silicon 버전) |
| make | `make --version` | `xcode-select --install` |
| 디스크 여유 | | small 약 1GB, full 약 5GB |

Docker Desktop 앱이 **켜져 있어야** 합니다 (메뉴바에 고래 아이콘).

## 2. 빠른 시작

```bash
make up                 # 1) MySQL 실행 + 테이블 생성 (처음 1회는 이미지 다운로드로 1~3분)
make seed               # 2) 더미 데이터 생성 (SCALE=small, 1분 이내)
make status             # 3) 테이블 행 수 · 크기 · 인덱스 확인
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=before   # 4) 첫 측정
```

4번을 처음 실행하면 측정 도구 이미지를 한 번 빌드합니다 (30초 정도).
결과는 화면에 나오고, `results/E01_single_filter/` 에 `.md`(사람이 읽는 용) + `.json`(비교용)으로 저장됩니다.

익숙해지면 PDF와 같은 규모로 다시 만듭니다.

```bash
make seed SCALE=full    # users 100만, products 100만, posts 100만, likes 약 950만 (맥 성능에 따라 수 분)
```

## 3. 실험 한 번의 흐름

```bash
make reset-indexes                                    # ① 출발점: PRIMARY KEY 만 남기기
make bench Q=experiments/E01_.../q1_xxx.sql L=before  # ② 인덱스 전 측정
make sql   F=experiments/E01_.../index_b_xxx.sql      # ③ 인덱스 추가
make bench Q=experiments/E01_.../q1_xxx.sql L=after   # ④ 같은 쿼리 · 같은 파라미터로 다시 측정
make compare E=E01                                    # ⑤ 전후 비교표 (results/E01_.../COMPARE.md 로도 저장)
```

그다음 실험 폴더의 `README.md` 기록 칸에 **가설 → 결과 → 결론**을 적습니다.

> 💡 실험 순서: 쿼리를 돌리기 **전에** 가설("풀스캔이라 20만 행을 읽을 것이다")을 먼저 적으세요. 결과가 예상과 다를 때가 가장 많이 배우는 순간입니다.

## 4. 명령어 모음

| 명령어 | 하는 일 |
|---|---|
| `make up` / `make down` | MySQL 켜기 / 끄기 (데이터는 유지) |
| `make destroy` | MySQL 과 데이터를 완전히 삭제 (처음부터 다시) |
| `make seed SCALE=small\|full` | 더미 데이터 새로 생성 (기존 데이터·인덱스 삭제) |
| `make status` | 테이블 행 수, 크기, 현재 인덱스 목록 |
| `make reset-indexes` | PRIMARY KEY 외 모든 인덱스·외래 키 삭제 |
| `make sql F=파일` | SQL 파일 실행 (인덱스 추가 등) |
| `make query Q=파일 [P='이름=값']` | 쿼리를 한 번 실행하고 결과 보기 |
| `make explain Q=파일 [P='이름=값']` | 측정 없이 실행 계획만 보기 |
| `make bench Q=파일 L=라벨 [P='이름=값 이름=값']` | 반복 측정 후 저장 |
| `make compare E=E01` | 그 실험의 측정 결과를 라벨별로 비교 |
| `make shell` | MySQL 콘솔 접속 (직접 SQL 입력, 나가기 `exit`) |
| `make slowlog` | 느린 쿼리 로그 (0.2초 이상) |

파라미터 바꾸기 예시:

```bash
make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=after_seller1 P='sellerId=1'
make bench Q=experiments/E09_antipatterns/c2_phone_string.sql L=x P="phone='01000012345'"   # 문자열은 작은따옴표
make bench Q=... L=x ARGS='--runs 50 --warmup 10'                                           # 측정 횟수 변경
```

DBeaver 같은 GUI 툴로 보고 싶다면: `localhost:13306`, 사용자 `root`, 비밀번호 `root`, DB `lab`
(맥에 다른 MySQL이 3306을 쓰고 있어도 충돌하지 않도록 **13306** 포트를 씁니다.)

## 5. 폴더 구조

```
db-index-lab/
├── README.md                 ← 지금 이 문서
├── docker-compose.yml        MySQL 8.4 + 측정 도구 컨테이너
├── Makefile                  명령어 모음
├── mysql/
│   ├── conf.d/lab.cnf        실습용 MySQL 설정 (버퍼 풀 1GB, 느린 쿼리 로그 등)
│   └── init/01_schema.sql    테이블 6개 (PRIMARY KEY 만 있는 상태)
├── sql/
│   ├── seed/seed.sql         더미 데이터 생성 (항상 같은 데이터가 나오도록 고정)
│   └── tools/                reset_indexes, status, index_sizes
├── bench/bench.py            측정 도구 (반복 실행, 백분위수, 실행 계획 저장, 비교)
├── experiments/              E01 ~ E12 실험 (폴더마다 README + 쿼리 + 인덱스 SQL)
├── results/                  측정 결과가 쌓이는 곳 (커밋해서 기록으로 남기세요)
├── docs/
│   ├── 00_기초개념.md        인덱스가 왜 빠른지: 디스크·페이지·B-tree부터
│   ├── 01_실행계획_읽는법.md EXPLAIN / EXPLAIN ANALYZE 읽는 법
│   ├── 02_측정_원칙.md       믿을 수 있는 측정을 위한 규칙과 이 도구의 한계
│   ├── 03_데이터_설명.md     테이블 구조, 데이터 분포, 실험에 쓰기 좋은 값
│   ├── PLAN.md               4주 계획
│   └── 면접답변_내버전.md     4주차: 내가 측정한 숫자로 면접 답변 다시 쓰기
└── templates/실험기록.md     새 실험을 직접 만들 때 쓰는 양식
```

## 6. 실험 목록

| 주차 | 실험 | 주제 | 자료 |
|---|---|---|---|
| 1 | [E01](experiments/E01_single_filter) | 풀스캔 vs 인덱스, 단일 vs 복합 | 1-1 |
| 1 | [E02](experiments/E02_join_and_unique) | 조인 키 인덱스, UNIQUE로 무결성까지 | 1-2 |
| 1 | [E03](experiments/E03_low_selectivity) | 값 종류가 적은 컬럼의 인덱스 | 3-1, 3-2 |
| 2 | [E04](experiments/E04_leftmost_prefix) | 복합 인덱스는 왼쪽부터 | 2 |
| 2 | [E05](experiments/E05_order_by) | 정렬과 filesort | 1-3 |
| 2 | [E06](experiments/E06_equality_first) | 등치 조건 먼저 vs 범위 조건 먼저 | 9 |
| 2 | [E07](experiments/E07_covering) | 커버링 인덱스와 SELECT * | 1-5 |
| 3 | [E08](experiments/E08_pagination) | OFFSET vs 커서 페이지네이션 | 1-4 |
| 3 | [E09](experiments/E09_antipatterns) | 인덱스를 못 타게 만드는 쿼리 모양 | 3-4 |
| 3 | [E10](experiments/E10_redundant_index) | 중복 인덱스 찾기와 안전한 제거 | 3-5 |
| 4 | [E11](experiments/E11_write_cost) | 인덱스가 늘면 INSERT는 얼마나 느려지나 | 3-3 |
| 4 | [E12](experiments/E12_denormalization) | like_count 반정규화와 정합성 | 4 |

## 7. 문제 해결

| 증상 | 해결 |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop 앱을 실행하고 고래 아이콘이 뜰 때까지 기다리기 |
| `docker: unknown command: docker compose` | Docker Desktop 이 설치되지 않음 (Homebrew 의 docker 명령어만 있는 상태) → Docker Desktop 설치 |
| `port is already allocated` (13306) | `docker-compose.yml` 의 `"13306:3306"` 앞 숫자를 다른 번호로 |
| `make seed SCALE=full` 이 너무 오래 걸림 | Docker Desktop → Settings → Resources 에서 CPU·메모리 늘리기 (메모리 4GB 이상 권장) |
| 데이터가 이상해짐 / 처음부터 다시 | `make destroy && make up && make seed` |
| `make: *** ... Error 1` (E02 중복 INSERT) | 일부러 에러를 내는 실험입니다. 에러 메시지 내용을 확인하세요 |

## 8. 주의

- `mysql/conf.d/lab.cnf` 는 **데이터를 빨리 넣기 위한 실습 전용 설정**입니다 (바이너리 로그 끔, 커밋 시 디스크 동기화 완화). 운영 DB에 그대로 쓰지 마세요.
- 비밀번호 `root` 도 실습용입니다.
- 측정 결과는 **내 맥 · Docker · 혼자 실행**이라는 조건의 값입니다. 운영 환경의 수치로 일반화하지 마세요 → [측정 원칙](docs/02_측정_원칙.md)
