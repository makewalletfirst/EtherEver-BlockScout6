#!/bin/bash

COMPOSE_FILE="/root/blockscout/docker-compose/docker-compose.yml"
PREV_COUNT=-1

# 자동 감지
DB_SERVICE=$(docker compose -f "$COMPOSE_FILE" ps --services | grep -E '^(postgresql|db)$' | head -1)
[ -z "$DB_SERVICE" ] && DB_SERVICE="db"

INDEXER_SERVICE=""
for svc in backend indexer blockscout app; do
    if docker compose -f "$COMPOSE_FILE" logs "$svc" 2>/dev/null | grep -q "Index had to catch up"; then
        INDEXER_SERVICE="$svc"; break
    fi
done
[ -z "$INDEXER_SERVICE" ] && INDEXER_SERVICE="backend"

clear
echo "========================================================================================================================"
echo "       Blockscout Full Realtime Monitor (Update every 7s) - DB: $DB_SERVICE / Logs: $INDEXER_SERVICE"
echo "========================================================================================================================"
printf "%-21s | %-12s | %-10s | %-15s | %-12s | %-12s | %s\n" "Timestamp" "Total Blks" "Inc/7s" "Latest Hgt" "DB Size" "LoadAvg" "Latest Catchup"
echo "-------------------------------------------------------------------------------------------------------------------------"

# 백그라운드 로그 감시
docker compose -f "$COMPOSE_FILE" logs -f "$INDEXER_SERVICE" 2>/dev/null | \
    grep --line-buffered "Index had to catch up" | \
    while IFS= read -r line; do echo "$line" > /tmp/blockscout_catchup.log; done &
LOG_PID=$!

trap 'kill $LOG_PID 2>/dev/null; rm -f /tmp/blockscout_catchup.log 2>/dev/null; echo; echo "모니터링 종료. 수고하셨습니다!"; exit' INT TERM

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    TODAY=$(date '+%y-%m-%d')   # 25-12-08 형식

    CURRENT_COUNT=$(docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" psql -U blockscout -d blockscout -t -c "SELECT count(*) FROM blocks;" 2>/dev/null | tr -d '[:space:]')
    [ -z "$CURRENT_COUNT" ] && CURRENT_COUNT="?"

    MAX_HEIGHT=$(docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" psql -U blockscout -d blockscout -t -c "SELECT MAX(number) FROM blocks;" 2>/dev/null | tr -d '[:space:]')
    [ -z "$MAX_HEIGHT" ] && MAX_HEIGHT="?"

    DB_SIZE=$(docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" psql -U blockscout -d blockscout -t -c "SELECT pg_size_pretty(pg_database_size('blockscout'));" 2>/dev/null | tr -d '[:space:]')
    [ -z "$DB_SIZE" ] && DB_SIZE="?"

    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',' | xargs printf "%.2f")

    # 증가량
    if [ "$PREV_COUNT" = "-1" ]; then
        DIFF="Start"
    else
        if [[ "$CURRENT_COUNT" =~ ^[0-9]+$ ]] && [[ "$PREV_COUNT" =~ ^[0-9]+$ ]]; then
            DIFF=$((CURRENT_COUNT - PREV_COUNT))
            [ $DIFF -gt 0 ] && DIFF="+$DIFF" || DIFF="$DIFF"
        else
            DIFF="?"
        fi
    fi

    # 캐치업 로그 파싱 (깔끔하게!)
    if [ -f /tmp/blockscout_catchup.log ] && [ -s /tmp/blockscout_catchup.log ]; then
        RAW=$(tail -1 /tmp/blockscout_catchup.log)
        FIRST=$(echo "$RAW" | grep -o '"first_block_number":[0-9]*' | grep -o '[0-9]*' | tail -1)
        LAST=$(echo "$RAW" | grep -o '"last_block_number":[0-9]*' | grep -o '[0-9]*' | tail -1)
        HMS=$(date '+%H:%M:%S')
        CATCHUP="Catchup $TODAY $HMS $FIRST → $LAST"
    else
        CATCHUP="No catchup"
    fi

    # 최종 출력 (색상도 완벽)
    echo -e "$(printf "%-21s | %-12s | \033[1;32m%-10s\033[0m | %-15s | \033[1;34m%-12s\033[0m | \033[1;33m%-12s\033[0m | " \
        "$TIMESTAMP" "$CURRENT_COUNT" "$DIFF" "$MAX_HEIGHT" "$DB_SIZE" "$LOAD")\
\033[1;31m$CATCHUP\033[0m"

    PREV_COUNT=$CURRENT_COUNT
    sleep 7
done
