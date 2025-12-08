#!/bin/bash

COMPOSE_FILE="/root/blockscout/docker-compose/docker-compose.yml"
PREV_COUNT=-1

echo "================================================================================================"
echo " Blockscout Sync Monitor (Update every 7s) - Press Ctrl+C to stop"
echo "================================================================================================"
printf "%-21s | %-12s | %-12s | %-15s | %-12s\n" "Timestamp" "Total Blocks" "Inc/7s" "Latest Height" "DB Size"
echo "------------------------------------------------------------------------------------------------"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # 1. 총 블록 수
    CURRENT_COUNT=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT count(*) FROM blocks;" 2>/dev/null | tr -d '[:space:]')
    [ -z "$CURRENT_COUNT" ] && CURRENT_COUNT=0

    # 2. 최신 블록 높이
    MAX_HEIGHT=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT MAX(number) FROM blocks;" 2>/dev/null | tr -d '[:space:]')
    [ -z "$MAX_HEIGHT" ] && MAX_HEIGHT="N/A"

    # 3. DB 크기 (sas 역할)
    DB_SIZE=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT pg_size_pretty(pg_database_size('blockscout'));" 2>/dev/null | tr -d '[:space:]')
    [ -z "$DB_SIZE" ] && DB_SIZE="N/A"

    # 4. 증가량 계산
    if [ "$PREV_COUNT" -eq -1 ]; then
        DIFF="Start"
    else
        DIFF=$((CURRENT_COUNT - PREV_COUNT))
        [ "$DIFF" -ge 0 ] && DIFF="+$DIFF" || DIFF="$DIFF"
    fi

    # 5. 출력 (녹색으로 증가량 강조)
    printf "%-21s | %-12s | \033[1;32m%-12s\033[0m | %-15s | \033[1;34m%-12s\033[0m\n" \
        "$TIMESTAMP" "$CURRENT_COUNT" "$DIFF" "$MAX_HEIGHT" "$DB_SIZE"

    PREV_COUNT=$CURRENT_COUNT
    sleep 7
done
