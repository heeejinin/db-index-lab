#!/usr/bin/env python3
"""
DB 인덱스 실습용 측정 도구

  run      쿼리를 워밍업 후 N번 반복 실행 → 평균/p50/p95/p99, 읽은 행 수, EXPLAIN, EXPLAIN ANALYZE 저장
  explain  측정 없이 실행 계획만 빠르게 확인
  query    쿼리를 한 번 실행하고 결과 행 보기
  compare  실험 폴더의 측정 결과(라벨별 최신)를 표 하나로 비교

보통은 직접 실행하지 않고 Makefile 로 실행합니다.
  make bench   Q=experiments/E01_.../q1_xxx.sql L=before
  make explain Q=experiments/E01_.../q1_xxx.sql
  make compare E=E01

쿼리 파일 형식 (맨 위 주석에 설정을 적습니다)
  -- @title  판매자별 판매 중 상품
  -- @param  sellerId = 500        숫자
  -- @param  status   = 'ON_SALE'  문자열은 따옴표
  -- @runs   30                    (선택) 측정 횟수
  -- @warmup 5                     (선택) 워밍업 횟수
  -- @mode   write                 (선택) INSERT/UPDATE/DELETE: 매번 ROLLBACK 해서 데이터가 바뀌지 않음
  SELECT ... WHERE seller_id = :sellerId AND status = :status;
"""

import argparse
import datetime as dt
import glob
import json
import math
import os
import re
import statistics
import sys
import time

import pymysql

ROOT = os.environ.get("LAB_ROOT", "/lab")
LAB_TABLES = ["users", "sellers", "categories", "products", "posts", "likes", "seq"]


# ----------------------------------------------------------------------------
# 쿼리 파일 읽기
# ----------------------------------------------------------------------------
def parse_value(raw):
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "'\"":
        return raw[1:-1]
    if raw.upper() == "NULL":
        return None
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    if re.fullmatch(r"-?\d+\.\d+", raw):
        return float(raw)
    return raw


def load_query(path):
    full = path if os.path.isabs(path) else os.path.join(ROOT, path)
    if not os.path.exists(full):
        sys.exit(f"[오류] 쿼리 파일이 없습니다: {path}")
    meta = {"title": "", "params": {}, "runs": None, "warmup": None, "mode": "read"}
    body = []
    with open(full, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"\s*--\s*@(\w+)\s*(.*)$", line)
            if m:
                key, val = m.group(1).lower(), m.group(2).strip()
                if key == "param":
                    name, _, v = val.partition("=")
                    meta["params"][name.strip()] = parse_value(v)
                elif key in ("runs", "warmup"):
                    meta[key] = int(val)
                elif key in ("title", "mode"):
                    meta[key] = val
                continue
            if re.match(r"\s*--", line):
                continue
            body.append(line)
    sql = "".join(body).strip().rstrip(";").strip()
    if not sql:
        sys.exit(f"[오류] 쿼리 본문이 비어 있습니다: {path}")
    if ";" in sql:
        sys.exit("[오류] 쿼리 파일에는 SQL 문장을 하나만 넣어 주세요.")
    return full, sql, meta


def merged_params(meta, a):
    """파일의 -- @param 기본값 위에 명령줄 값(-p 이름=값, --params "이름=값 이름='문자열 값'")을 덮어씀"""
    params = dict(meta["params"])
    for p in getattr(a, "param", None) or []:
        k, _, v = p.partition("=")
        params[k.strip()] = parse_value(v)
    raw = getattr(a, "params", None) or ""
    for k, v in re.findall(r"(\w+)\s*=\s*('[^']*'|\"[^\"]*\"|\S+)", raw):
        params[k] = parse_value(v)
    return params


def to_pymysql(sql, params):
    """:name 형식 파라미터를 pymysql 형식(%(name)s)으로 바꿈"""
    used = set(re.findall(r"(?<![:\w]):([A-Za-z_]\w*)", sql))
    missing = used - set(params)
    if missing:
        sys.exit(f"[오류] 값이 없는 파라미터: {', '.join(sorted(missing))}  (-- @param 또는 P='이름=값' 으로 지정)")
    converted = sql.replace("%", "%%")
    converted = re.sub(r"(?<![:\w]):([A-Za-z_]\w*)", r"%(\1)s", converted)
    return converted


def experiment_of(full_path):
    rel = os.path.relpath(full_path, ROOT)
    parts = rel.split(os.sep)
    if len(parts) >= 3 and parts[0] == "experiments":
        return parts[1]
    return "misc"


# ----------------------------------------------------------------------------
# DB
# ----------------------------------------------------------------------------
def connect():
    last = None
    for _ in range(30):
        try:
            return pymysql.connect(
                host=os.environ.get("DB_HOST", "127.0.0.1"),
                port=int(os.environ.get("DB_PORT", "13306")),
                user=os.environ.get("DB_USER", "root"),
                password=os.environ.get("DB_PASSWORD", "root"),
                database=os.environ.get("DB_NAME", "lab"),
                charset="utf8mb4",
                autocommit=True,
            )
        except pymysql.err.OperationalError as e:
            last = e
            time.sleep(1)
    sys.exit(f"[오류] MySQL 에 연결할 수 없습니다. make up 을 먼저 실행했나요? ({last})")


def fetch(cur, sql, args=None):
    cur.execute(sql, args)
    cols = [d[0] for d in cur.description] if cur.description else []
    return cols, cur.fetchall()


LAST_STMT_SQL = """
SELECT TIMER_WAIT, ROWS_EXAMINED, ROWS_SENT, ROWS_AFFECTED,
       NO_INDEX_USED, SELECT_SCAN, SELECT_RANGE, SORT_ROWS, SORT_SCAN,
       SORT_MERGE_PASSES, CREATED_TMP_TABLES, CREATED_TMP_DISK_TABLES
FROM performance_schema.events_statements_history
WHERE THREAD_ID = PS_CURRENT_THREAD_ID()
ORDER BY EVENT_ID DESC
LIMIT 1
"""


def last_statement(cur):
    """방금 실행한 쿼리의 서버 측 통계 (performance_schema)"""
    cols, rows = fetch(cur, LAST_STMT_SQL)
    if not rows:
        return None
    return dict(zip([c.lower() for c in cols], rows[0]))


def execute_once(conn, sql, args, mode):
    """한 번 실행하고 (클라이언트 측 ms, 결과 행 수, 서버 통계) 반환"""
    with conn.cursor() as cur:
        if mode == "write":
            conn.begin()
        t0 = time.perf_counter()
        cur.execute(sql, args)
        rows = cur.fetchall() if cur.description else ()
        client_ms = (time.perf_counter() - t0) * 1000
        n_rows = len(rows) if cur.description else cur.rowcount
        stmt = last_statement(cur)
        if mode == "write":
            conn.rollback()
    return client_ms, n_rows, stmt


HANDLER_KEYS = [
    ("Handler_read_key", "인덱스로 위치 찾기"),
    ("Handler_read_next", "인덱스 순서대로 다음 행"),
    ("Handler_read_prev", "인덱스 역순으로 이전 행"),
    ("Handler_read_first", "인덱스 첫 항목"),
    ("Handler_read_last", "인덱스 마지막 항목"),
    ("Handler_read_rnd_next", "테이블 순차 스캔(풀스캔)"),
    ("Handler_read_rnd", "위치로 행 다시 읽기(정렬 후 등)"),
]


ICP_SQL = ("SELECT NAME, COUNT FROM information_schema.INNODB_METRICS "
           "WHERE NAME IN ('icp_attempts', 'icp_no_match', 'icp_out_of_range', 'icp_match')")


def _handler(cur):
    cur.execute("SHOW SESSION STATUS LIKE 'Handler_read%'")
    return {k: int(v) for k, v in cur.fetchall()}


def _icp(cur):
    cur.execute(ICP_SQL)
    return {k: int(v) for k, v in cur.fetchall()}


def handler_reads(conn, sql, args, mode):
    """한 번 더 실행하면서 스토리지 엔진이 실제로 훑은 행·인덱스 항목 수를 셈.

    - Handler_read_* : 엔진이 MySQL 서버에 넘겨준 행 (세션 단위)
    - icp_*          : 인덱스 안에서 조건을 검사하고 "넘기기 전에 버린" 항목 (Using index condition)
    rows_examined 와 Handler 값은 ICP 로 버린 항목을 세지 않기 때문에 둘을 더해서 봅니다.
    (icp_* 는 서버 전체 카운터라서, 측정 중에 다른 쿼리를 돌리지 않는 것이 좋습니다)"""
    with conn.cursor() as cur:
        # 카운터를 읽는 쿼리 자체가 Handler 값을 올리지 않도록 순서를 맞춤
        before = _icp(cur)
        before.update(_handler(cur))
        if mode == "write":
            conn.begin()
        cur.execute(sql, args)
        if cur.description:
            cur.fetchall()
        if mode == "write":
            conn.rollback()
        after = _handler(cur)
        after.update(_icp(cur))
    keys = [k for k, _ in HANDLER_KEYS] + ["icp_attempts", "icp_no_match", "icp_out_of_range", "icp_match"]
    delta = {k: after.get(k, 0) - before.get(k, 0) for k in keys}
    delta["handler_total"] = sum(delta[k] for k, _ in HANDLER_KEYS)
    delta["icp_filtered"] = delta["icp_no_match"] + delta["icp_out_of_range"]
    delta["total"] = delta["handler_total"] + delta["icp_filtered"]
    return delta


def table_names(sql):
    found = re.findall(r"\b(?:FROM|JOIN|INTO|UPDATE)\s+`?(\w+)`?", sql, flags=re.I)
    seen = []
    for t in found:
        t = t.lower()
        if t in LAB_TABLES and t not in seen:
            seen.append(t)
    return seen


def index_info(cur, tables):
    info = {}
    for t in tables:
        _, rows = fetch(cur, f"SHOW INDEX FROM `{t}`")
        idx = {}
        for r in rows:
            # Table, Non_unique, Key_name, Seq_in_index, Column_name, ... Visible(13), Expression(14)
            name, non_unique, col, visible = r[2], r[1], r[4] or f"({r[14]})", r[13]
            d = idx.setdefault(name, {"cols": [], "unique": non_unique == 0, "visible": visible == "YES"})
            d["cols"].append(col)
        info[t] = [
            f"{n}({', '.join(d['cols'])})" + (" UNIQUE" if d["unique"] and n != "PRIMARY" else "")
            + ("" if d["visible"] else " INVISIBLE")
            for n, d in idx.items()
        ]
    return info


def table_rows(cur, tables):
    if not tables:
        return {}
    cur.execute("SET SESSION information_schema_stats_expiry = 0")
    marks = ",".join(["%s"] * len(tables))
    _, rows = fetch(
        cur,
        f"SELECT TABLE_NAME, TABLE_ROWS FROM information_schema.TABLES "
        f"WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ({marks})",
        tables,
    )
    return {r[0]: int(r[1] or 0) for r in rows}


# ----------------------------------------------------------------------------
# 통계 / 출력
# ----------------------------------------------------------------------------
def pct(sorted_vals, p):
    """nearest-rank 방식 백분위수"""
    if not sorted_vals:
        return None
    k = max(1, math.ceil(p / 100 * len(sorted_vals)))
    return sorted_vals[k - 1]


def summarize(vals):
    s = sorted(vals)
    return {
        "avg": statistics.fmean(s),
        "p50": pct(s, 50),
        "p95": pct(s, 95),
        "p99": pct(s, 99),
        "min": s[0],
        "max": s[-1],
        "stdev": statistics.pstdev(s) if len(s) > 1 else 0.0,
    }


def fmt_ms(v):
    if v is None:
        return "-"
    return f"{v:.2f}" if v < 100 else f"{v:.0f}"


def md_table(cols, rows):
    def cell(v):
        return "NULL" if v is None else str(v).replace("|", "\\|").replace("\n", " ")
    out = ["| " + " | ".join(cols) + " |", "|" + "|".join(["---"] * len(cols)) + "|"]
    for r in rows:
        out.append("| " + " | ".join(cell(v) for v in r) + " |")
    return "\n".join(out)


def explain(cur, sql, args, mode):
    result = {}
    cols, rows = fetch(cur, "EXPLAIN " + sql, args)
    result["explain_cols"] = cols
    result["explain_rows"] = [list(r) for r in rows]
    if mode != "write" and re.match(r"\s*(SELECT|WITH|TABLE)\b", sql, flags=re.I):
        _, rows = fetch(cur, "EXPLAIN ANALYZE " + sql, args)
        result["explain_analyze"] = rows[0][0] if rows else ""
    else:
        _, rows = fetch(cur, "EXPLAIN FORMAT=TREE " + sql, args)
        result["explain_tree"] = rows[0][0] if rows else ""
    return result


def explain_summary(cols, rows):
    """EXPLAIN 표에서 테이블별 type / key / Extra 만 뽑아 한 줄로"""
    if not rows:
        return "-", "-", "-"
    ci = {c: i for i, c in enumerate(cols)}
    types, keys, extras = [], [], []
    for r in rows:
        tbl = r[ci["table"]]
        types.append(f"{tbl}:{r[ci['type']]}")
        keys.append(f"{tbl}:{r[ci['key']] or '없음'}")
        if r[ci["Extra"]]:
            extras.append(f"{tbl}:{r[ci['Extra']]}")
    return " / ".join(types), " / ".join(keys), " / ".join(extras) or "-"


def print_explain(ex):
    print("\n--- EXPLAIN (옵티마이저의 계획) ---")
    print(md_table(ex["explain_cols"], ex["explain_rows"]))
    if "explain_analyze" in ex:
        print("\n--- EXPLAIN ANALYZE (실제로 실행한 결과) ---")
        print(ex["explain_analyze"])
    elif "explain_tree" in ex:
        print("\n--- EXPLAIN FORMAT=TREE (쓰기 쿼리는 ANALYZE 대신 계획만) ---")
        print(ex["explain_tree"])


# ----------------------------------------------------------------------------
# 명령: run
# ----------------------------------------------------------------------------
def cmd_run(a):
    full, raw_sql, meta = load_query(a.query)
    params = merged_params(meta, a)
    runs = a.runs or meta["runs"] or 30
    warmup = a.warmup if a.warmup is not None else (meta["warmup"] if meta["warmup"] is not None else 5)
    mode = meta["mode"]
    sql = to_pymysql(raw_sql, params)
    exp = experiment_of(full)
    qname = os.path.splitext(os.path.basename(full))[0]
    label = a.label or "run"

    conn = connect()
    with conn.cursor() as cur:
        rendered = cur.mogrify(sql, params)
        _, v = fetch(cur, "SELECT VERSION(), @@innodb_buffer_pool_size")
        version, bp = v[0]

    print(f"\n=== {exp} / {qname}  [{label}] ===")
    if meta["title"]:
        print(meta["title"])
    print(f"파라미터: {params or '없음'}")
    print(f"워밍업 {warmup}회 → 측정 {runs}회" + ("  (쓰기 모드: 매번 ROLLBACK)" if mode == "write" else ""))

    for _ in range(warmup):
        execute_once(conn, sql, params, mode)

    client, server, last = [], [], None
    n_rows = None
    for i in range(runs):
        c_ms, n_rows, stmt = execute_once(conn, sql, params, mode)
        client.append(c_ms)
        if stmt and stmt.get("timer_wait") is not None:
            server.append(stmt["timer_wait"] / 1e9)  # 피코초 → ms
        last = stmt
        print(f"\r  측정 중... {i + 1}/{runs}", end="", flush=True)
    print()

    cs, ss = summarize(client), (summarize(server) if server else None)
    handler = handler_reads(conn, sql, params, mode)

    with conn.cursor() as cur:
        ex = explain(cur, sql, params, mode) if not a.no_explain else {}
        tables = table_names(raw_sql)
        idx = index_info(cur, tables)
        trows = table_rows(cur, tables)
    conn.close()

    print(f"\n결과 행 수: {n_rows}")
    print("\n시간(ms)        avg      p50      p95      p99      min      max")
    if ss:
        print("서버 실행  " + "".join(f"{fmt_ms(ss[k]):>9}" for k in ("avg", "p50", "p95", "p99", "min", "max")))
    print("클라이언트 " + "".join(f"{fmt_ms(cs[k]):>9}" for k in ("avg", "p50", "p95", "p99", "min", "max")))
    if last:
        print(
            f"\n읽은 행 수(rows_examined): {last['rows_examined']:,}   보낸 행 수(rows_sent): {last['rows_sent']:,}"
            f"   정렬한 행 수(sort_rows): {last['sort_rows']:,}"
            f"   인덱스 없이 실행(no_index_used): {'예' if last['no_index_used'] else '아니오'}"
        )
    print(f"엔진이 훑은 행·인덱스 항목 수: {handler['total']:,}  →  "
          + ", ".join(f"{desc} {handler[k]:,}" for k, desc in HANDLER_KEYS if handler[k])
          + (f", 인덱스 안에서 검사 후 버림(ICP) {handler['icp_filtered']:,}" if handler["icp_filtered"] else ""))
    if ex:
        print_explain(ex)
    print("\n--- 관련 테이블 인덱스 ---")
    for t, lst in idx.items():
        print(f"  {t} (약 {trows.get(t, 0):,}행): {', '.join(lst)}")

    record = {
        "experiment": exp,
        "query": qname,
        "query_file": os.path.relpath(full, ROOT),
        "title": meta["title"],
        "label": label,
        "measured_at": dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "params": params,
        "sql": rendered,
        "mode": mode,
        "runs": runs,
        "warmup": warmup,
        "result_rows": n_rows,
        "client_ms": cs,
        "server_ms": ss,
        "last_statement": last,
        "handler_reads": handler,
        "explain": ex,
        "indexes": idx,
        "table_rows": trows,
        "env": {"mysql_version": version, "innodb_buffer_pool_size_mb": int(bp) // 1024 // 1024},
    }
    if not a.no_save:
        out_dir = os.path.join(ROOT, "results", exp)
        os.makedirs(out_dir, exist_ok=True)
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        safe_label = re.sub(r"[^\w.-]+", "_", label)
        base = os.path.join(out_dir, f"{qname}__{safe_label}__{stamp}")
        with open(base + ".json", "w", encoding="utf-8") as f:
            json.dump(record, f, ensure_ascii=False, indent=2, default=str)
        with open(base + ".md", "w", encoding="utf-8") as f:
            f.write(render_md(record))
        print(f"\n저장: {os.path.relpath(base, ROOT)}.md (.json)")
        print(f"전후 비교: make compare E={exp.split('_')[0]}")


def render_md(r):
    lines = [f"# {r['experiment']} / {r['query']} [{r['label']}]", ""]
    if r["title"]:
        lines += [r["title"], ""]
    lines += [
        f"- 측정 시각: {r['measured_at']}",
        f"- MySQL {r['env']['mysql_version']}, buffer pool {r['env']['innodb_buffer_pool_size_mb']}MB",
        f"- 워밍업 {r['warmup']}회, 측정 {r['runs']}회, 모드 {r['mode']}",
        f"- 파라미터: `{r['params']}`",
        f"- 결과 행 수: {r['result_rows']}",
        "",
        "## 실행한 SQL",
        "```sql",
        r["sql"],
        "```",
        "",
        "## 시간 (ms)",
    ]
    rows = []
    if r["server_ms"]:
        rows.append(["서버 실행"] + [fmt_ms(r["server_ms"][k]) for k in ("avg", "p50", "p95", "p99", "min", "max")])
    rows.append(["클라이언트"] + [fmt_ms(r["client_ms"][k]) for k in ("avg", "p50", "p95", "p99", "min", "max")])
    lines += [md_table(["", "avg", "p50", "p95", "p99", "min", "max"], rows), ""]
    if r["last_statement"]:
        s = r["last_statement"]
        lines += [
            "## 서버 통계 (마지막 1회, performance_schema)",
            md_table(
                ["rows_examined", "rows_sent", "sort_rows", "no_index_used", "select_scan", "created_tmp_tables"],
                [[s["rows_examined"], s["rows_sent"], s["sort_rows"], s["no_index_used"], s["select_scan"], s["created_tmp_tables"]]],
            ),
            "",
        ]
    h = r.get("handler_reads")
    if h:
        lines += [
            f"## 엔진이 훑은 행·인덱스 항목 (합계 {h['total']:,})",
            md_table([desc for _, desc in HANDLER_KEYS] + ["인덱스 안에서 검사 후 버림(ICP)"],
                     [[f"{h[k]:,}" for k, _ in HANDLER_KEYS] + [f"{h.get('icp_filtered', 0):,}"]]),
            "",
        ]
    ex = r["explain"]
    if ex:
        lines += ["## EXPLAIN", md_table(ex["explain_cols"], ex["explain_rows"]), ""]
        if "explain_analyze" in ex:
            lines += ["## EXPLAIN ANALYZE", "```", ex["explain_analyze"], "```", ""]
        elif "explain_tree" in ex:
            lines += ["## EXPLAIN FORMAT=TREE", "```", ex["explain_tree"], "```", ""]
    lines += ["## 관련 테이블 인덱스"]
    for t, lst in r["indexes"].items():
        lines.append(f"- {t} (약 {r['table_rows'].get(t, 0):,}행): {', '.join(lst)}")
    return "\n".join(lines) + "\n"


# ----------------------------------------------------------------------------
# 명령: explain
# ----------------------------------------------------------------------------
def cmd_explain(a):
    full, raw_sql, meta = load_query(a.query)
    params = merged_params(meta, a)
    sql = to_pymysql(raw_sql, params)
    conn = connect()
    with conn.cursor() as cur:
        print("\n" + cur.mogrify(sql, params))
        print_explain(explain(cur, sql, params, meta["mode"]))
        print("\n--- 관련 테이블 인덱스 ---")
        for t, lst in index_info(cur, table_names(raw_sql)).items():
            print(f"  {t}: {', '.join(lst)}")
    conn.close()


# ----------------------------------------------------------------------------
# 명령: query (한 번 실행하고 결과 출력)
# ----------------------------------------------------------------------------
def cmd_query(a):
    full, raw_sql, meta = load_query(a.query)
    params = merged_params(meta, a)
    sql = to_pymysql(raw_sql, params)
    conn = connect()
    with conn.cursor() as cur:
        print("\n" + cur.mogrify(sql, params) + "\n")
        if meta["mode"] == "write":
            conn.begin()
        cols, rows = fetch(cur, sql, params)
        if meta["mode"] == "write":
            conn.rollback()
            print(f"(쓰기 모드: {cur.rowcount}행 변경 후 ROLLBACK)")
        if cols:
            print(md_table(cols, [list(r) for r in rows[:50]]))
            print(f"\n{len(rows)}행" + (" (앞 50행만 표시)" if len(rows) > 50 else ""))
    conn.close()


# ----------------------------------------------------------------------------
# 명령: compare
# ----------------------------------------------------------------------------
def cmd_compare(a):
    files = []
    if len(a.targets) == 1 and not a.targets[0].endswith(".json"):
        t = a.targets[0]
        dirs = [d for d in glob.glob(os.path.join(ROOT, "results", "*")) if os.path.isdir(d)]
        match = [d for d in dirs if os.path.basename(d) == t or os.path.basename(d).split("_")[0] == t]
        if not match:
            sys.exit(f"[오류] results/ 아래에 '{t}' 실험 결과가 없습니다. 먼저 make bench 를 실행하세요.")
        out_dir = match[0]
        files = glob.glob(os.path.join(out_dir, "*.json"))
    else:
        files = [f if os.path.isabs(f) else os.path.join(ROOT, f) for f in a.targets]
        out_dir = None

    records = []
    for f in files:
        with open(f, encoding="utf-8") as fh:
            records.append(json.load(fh))
    if not records:
        sys.exit("[오류] 비교할 결과가 없습니다.")

    # (쿼리, 라벨) 마다 가장 최근 측정만 사용
    latest = {}
    for r in records:
        key = (r["query"], r["label"])
        if key not in latest or r["measured_at"] > latest[key]["measured_at"]:
            latest[key] = r
    chosen = sorted(latest.values(), key=lambda r: (r["query"], r["measured_at"]))

    cols = ["쿼리", "라벨", "서버 avg", "서버 p95", "클라 p95", "rows_examined", "훑은 항목", "결과 행", "type", "사용 인덱스", "Extra", "측정 시각"]
    rows = []
    for r in chosen:
        ex = r.get("explain") or {}
        typ, key, extra = explain_summary(ex.get("explain_cols", []), ex.get("explain_rows", []))
        s = r.get("server_ms") or {}
        last = r.get("last_statement") or {}
        rows.append([
            r["query"], r["label"], fmt_ms(s.get("avg")), fmt_ms(s.get("p95")), fmt_ms(r["client_ms"]["p95"]),
            f"{last.get('rows_examined', 0):,}", f"{(r.get('handler_reads') or {}).get('total', 0):,}", r["result_rows"], typ, key, extra, r["measured_at"][5:16],
        ])
    table = md_table(cols, rows)
    print("\n" + table)
    print("\n(시간 단위 ms · 서버 = MySQL 내부 실행 시간 · 클라 = 네트워크와 결과 전송 포함)")
    if out_dir:
        path = os.path.join(out_dir, "COMPARE.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"# {os.path.basename(out_dir)} 비교 ({dt.datetime.now():%Y-%m-%d %H:%M})\n\n")
            f.write("(쿼리·라벨별 가장 최근 측정 · 시간 단위 ms)\n\n" + table + "\n")
        print(f"저장: {os.path.relpath(path, ROOT)}")


def main():
    ap = argparse.ArgumentParser(description="DB 인덱스 실습 측정 도구")
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("run", help="반복 측정")
    r.add_argument("query")
    r.add_argument("--label", "-l")
    r.add_argument("--runs", type=int)
    r.add_argument("--warmup", type=int)
    r.add_argument("--param", "-p", action="append", help="이름=값 (여러 번 사용 가능)")
    r.add_argument("--params", help="여러 파라미터를 한 문자열로: \"a=1 b='문자열 값'\"")
    r.add_argument("--no-save", action="store_true")
    r.add_argument("--no-explain", action="store_true")
    r.set_defaults(func=cmd_run)

    e = sub.add_parser("explain", help="실행 계획만 보기")
    e.add_argument("query")
    e.add_argument("--param", "-p", action="append")
    e.add_argument("--params")
    e.set_defaults(func=cmd_explain)

    q = sub.add_parser("query", help="한 번 실행하고 결과 보기")
    q.add_argument("query")
    q.add_argument("--param", "-p", action="append")
    q.add_argument("--params")
    q.set_defaults(func=cmd_query)

    c = sub.add_parser("compare", help="결과 비교")
    c.add_argument("targets", nargs="+", help="실험 이름(E01) 또는 json 파일들")
    c.set_defaults(func=cmd_compare)

    a = ap.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
