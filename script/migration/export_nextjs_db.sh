#!/usr/bin/env bash
# Next.js (LibSQL/SQLite) DB → Rails import용 SQL/JSON dump
# 사용법: bash script/migration/export_nextjs_db.sh [출력디렉터리]

set -euo pipefail

NEXTJS_DB="/Volumes/E_SSD/02_GitHub.nosync/0008_choi-pd/choi-pd-ecosystem/data/database.db"
OUTPUT_DIR="${1:-tmp/nextjs_export}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ ! -f "$NEXTJS_DB" ]; then
  echo "❌ Next.js DB not found: $NEXTJS_DB"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
echo "📦 Exporting Next.js DB → $OUTPUT_DIR"

# 1. 전체 SQL dump (백업용)
echo "  [1/3] Full SQL dump..."
sqlite3 "$NEXTJS_DB" .dump > "$OUTPUT_DIR/full_dump_${TIMESTAMP}.sql"

# 2. 테이블 목록 추출
echo "  [2/3] Listing tables..."
sqlite3 "$NEXTJS_DB" ".tables" | tr -s ' ' '\n' | grep -v '^$' | sort > "$OUTPUT_DIR/tables.txt"
echo "    Found $(wc -l < $OUTPUT_DIR/tables.txt) tables"

# 3. 테이블별 JSON export (Rails seed에서 활용)
echo "  [3/3] Per-table JSON export..."
mkdir -p "$OUTPUT_DIR/json"
while IFS= read -r table; do
  count=$(sqlite3 "$NEXTJS_DB" "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "ERR")
  if [ "$count" = "ERR" ] || [ "$count" -eq 0 ]; then
    echo "    skip: $table (count=$count)"
    continue
  fi
  sqlite3 -json "$NEXTJS_DB" "SELECT * FROM $table" > "$OUTPUT_DIR/json/${table}.json"
  echo "    ✓ $table ($count rows)"
done < "$OUTPUT_DIR/tables.txt"

# 4. 스키마 (CREATE TABLE) 추출
echo "  [extra] Schema dump..."
sqlite3 "$NEXTJS_DB" ".schema" > "$OUTPUT_DIR/schema.sql"

echo "✅ Done. Output: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR" | head
