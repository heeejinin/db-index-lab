# ============================================================
# DB 인덱스 실습 명령어 모음 (사용법: make help)
# ============================================================
SHELL := /bin/bash
DC    := docker compose
MYSQL := $(DC) exec -T -e MYSQL_PWD=root mysql mysql -uroot --default-character-set=utf8mb4 lab
BENCH := $(DC) run --rm bench

SCALE ?= small
L     ?= run

.PHONY: help up down destroy shell status seed reset-indexes sql query bench explain compare logs slowlog

help: ## 명령어 목록
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-15s %s\n", $$1, $$2}'
	@echo ""
	@echo "  예) make seed SCALE=full"
	@echo "      make bench Q=experiments/E01_single_filter/q1_seller_on_sale.sql L=before"
	@echo "      make bench Q=... L=after P='sellerId=1'"
	@echo "      make sql F=experiments/E01_single_filter/index_b_seller_status.sql"

# ---------- 환경 ----------
up: ## MySQL 실행 (처음이면 테이블까지 생성)
	$(DC) up -d --wait mysql
	@echo "MySQL 준비 완료 → 다음: make seed"

down: ## MySQL 중지 (데이터는 유지)
	$(DC) down

destroy: ## MySQL 중지 + 데이터 완전 삭제 (처음 상태로)
	$(DC) down -v

shell: ## MySQL 콘솔 접속 (나가기: exit)
	$(DC) exec -e MYSQL_PWD=root mysql mysql -uroot --default-character-set=utf8mb4 lab

logs: ## MySQL 로그 보기
	$(DC) logs --tail=50 mysql

# ---------- 데이터 ----------
seed: ## 더미 데이터 생성 (SCALE=small|full, 기존 데이터 삭제됨)
	@echo "더미 데이터 생성: SCALE=$(SCALE) (기존 데이터와 보조 인덱스는 삭제됩니다)"
	@set -o pipefail; time $(MYSQL) -n -e "SET @scale='$(SCALE)'; SOURCE /lab/sql/seed/seed.sql;" | grep --line-buffered -v -E '^(progress|reset_indexes|Table)|analyze'

status: ## 테이블 행 수·크기·인덱스 목록
	@$(MYSQL) -t -e "SOURCE /lab/sql/tools/status.sql"

reset-indexes: ## PRIMARY KEY 외 모든 인덱스·외래 키 삭제 (실험 출발점으로)
	@$(MYSQL) -t -e "SOURCE /lab/sql/tools/reset_indexes.sql"

# ---------- 실험 ----------
sql: ## SQL 파일 실행 (F=경로)
	@test -n "$(F)" || (echo "F=실행할 SQL 파일 경로 를 지정하세요"; exit 1)
	@set -o pipefail; $(MYSQL) -t -vv -e "SOURCE /lab/$(F)" | grep -v -E '^(--------------|Bye)$$'

bench: ## 쿼리 반복 측정 후 results/ 에 저장 (Q=쿼리 파일, L=라벨, P='이름=값 ...')
	@test -n "$(Q)" || (echo "Q=측정할 쿼리 파일 경로 를 지정하세요"; exit 1)
	@$(BENCH) run $(Q) --label $(L) --params "$(P)" $(ARGS)

query: ## 쿼리 파일을 한 번 실행하고 결과 보기 (Q=쿼리 파일, P='이름=값')
	@test -n "$(Q)" || (echo "Q=쿼리 파일 경로 를 지정하세요"; exit 1)
	@$(BENCH) query $(Q) --params "$(P)"

explain: ## 측정 없이 실행 계획만 보기 (Q=쿼리 파일)
	@test -n "$(Q)" || (echo "Q=쿼리 파일 경로 를 지정하세요"; exit 1)
	@$(BENCH) explain $(Q) --params "$(P)"

compare: ## 실험 결과 전후 비교표 (E=E01)
	@test -n "$(E)" || (echo "E=실험 번호(E01 등) 를 지정하세요"; exit 1)
	@$(BENCH) compare $(E)

slowlog: ## 느린 쿼리 로그 마지막 40줄
	@$(DC) exec mysql tail -n 40 /var/lib/mysql/slow.log
