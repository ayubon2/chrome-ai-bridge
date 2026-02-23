#!/bin/bash
# chrome-ai-bridge ゾンビプロセス除去スクリプト
# 承認済みスクリプト（mcp-watchdog・手動実行用の安全なクリーンアップ）
# 使い方: bash scripts/cleanup_bridge.sh [--dry-run]

SCRIPT_NAME="cleanup_bridge"
DRY_RUN=false
LOCK_FILE="$HOME/.cache/chrome-ai-bridge/mcp.lock"

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "[$SCRIPT_NAME] 不明なオプション: $arg" >&2
      echo "使い方: bash scripts/cleanup_bridge.sh [--dry-run]" >&2
      exit 1
      ;;
  esac
done

if $DRY_RUN; then
  echo "[$SCRIPT_NAME] --- DRY RUN モード（実際のkillは実行しません） ---"
fi

# ===== プロセスホワイトリスト =====
# 対象パターン（chrome-ai-bridge のエントリポイントのみ）
PATTERN_INDEX="005_chrome-ai-bridge/build/src/index.js"
PATTERN_MAIN="005_chrome-ai-bridge/build/src/main.js"
PATTERN_CLI="005_chrome-ai-bridge/scripts/cli.mjs"

collect_pids() {
  ps -axo pid=,command= 2>/dev/null | while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    cmd=$(echo "$line" | cut -d' ' -f2-)
    case "$cmd" in
      *"$PATTERN_INDEX"*|*"$PATTERN_MAIN"*|*"$PATTERN_CLI"*)
        if [ "$pid" != "$$" ]; then
          echo "$pid $cmd"
        fi
        ;;
    esac
  done
}

echo "[$SCRIPT_NAME] chrome-ai-bridge プロセスをスキャン中..."
PROC_LIST=$(collect_pids)

if [ -z "$PROC_LIST" ]; then
  echo "[$SCRIPT_NAME] 対象プロセスなし（chrome-ai-bridge は稼働していません）"
  if [ -f "$LOCK_FILE" ]; then
    if $DRY_RUN; then
      echo "[$SCRIPT_NAME] [DRY RUN] ロックファイルを削除します: $LOCK_FILE"
    else
      rm -f "$LOCK_FILE"
      echo "[$SCRIPT_NAME] 残留ロックファイルを削除しました: $LOCK_FILE"
    fi
  fi
  exit 0
fi

echo "[$SCRIPT_NAME] 対象プロセス:"
while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $1}')
  cmd=$(echo "$line" | cut -d' ' -f2-)
  echo "  PID $pid: $cmd"
done <<< "$PROC_LIST"

if $DRY_RUN; then
  echo "[$SCRIPT_NAME] [DRY RUN] 上記プロセスを終了します（dry-runのため実際には何もしません）"
  exit 0
fi

echo "[$SCRIPT_NAME] 上記プロセスを終了します..."
PIDS=$(echo "$PROC_LIST" | awk '{print $1}')

TERM_COUNT=0
while IFS= read -r pid; do
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null && TERM_COUNT=$((TERM_COUNT + 1)) || true
  fi
done <<< "$PIDS"

echo "[$SCRIPT_NAME] SIGTERM を $TERM_COUNT プロセスに送信しました。2秒待機..."
sleep 2

KILL_COUNT=0
while IFS= read -r pid; do
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "[$SCRIPT_NAME] PID $pid がまだ生存中。SIGKILL を送信します..."
    kill -KILL "$pid" 2>/dev/null || true
    KILL_COUNT=$((KILL_COUNT + 1))
  fi
done <<< "$PIDS"

if [ -f "$LOCK_FILE" ]; then
  rm -f "$LOCK_FILE"
  echo "[$SCRIPT_NAME] ロックファイルを削除しました: $LOCK_FILE"
fi

echo ""
echo "[$SCRIPT_NAME] 完了。終了プロセス数: $((TERM_COUNT + KILL_COUNT))"
REMAINING=$(collect_pids | wc -l | tr -d ' ')
if [ "$REMAINING" -eq 0 ]; then
  echo "[$SCRIPT_NAME] chrome-ai-bridge プロセスはすべて終了しました。"
else
  echo "[$SCRIPT_NAME] 警告: $REMAINING プロセスが残存しています"
fi
