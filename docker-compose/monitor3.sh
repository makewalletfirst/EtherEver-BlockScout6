#!/bin/bash

COMPOSE_FILE="/root/blockscout/docker-compose/docker-compose.yml"
PREV_COUNT=-1

clear
echo "================================================================================================================"
echo "                Blockscout Real-time Sync Monitor (Update every 7s) - Ctrl+C to exit"
echo "================================================================================================================"
printf "%-21s | %-12s | %-12s | %-15s | %-12s | %-12s\n" "Timestamp" "Total Blocks" "Inc/7s" "Latest Height" "DB Size" "Load Avg"
echo "----------------------------------------------------------------------------------------------------------------"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # 1. 총 블록 수
    CURRENT_COUNT=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT count(*) FROM blocks;" 2>/dev/null | tr -d '[:space:]')
    [ -z "$CURRENT_COUNT" ] && CURRENT_COUNT=0

    # 2. 최신 블록 높이
    MAX_HEIGHT=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT MAX(number) FROM blocks;" 2>/dev/null | tr -d '[:space:]')
    [ -z "$MAX_HEIGHT" ] && MAX_HEIGHT="N/A"

    # 3. DB 크기
    DB_SIZE=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT pg_size_pretty(pg_database_size('blockscout'));" 2>/dev/null | tr -d '[:space:]')
    [ -z "$DB_SIZE" ] && DB_SIZE="N/A"

    # 4. CPU Load Average (1분 평균만 예쁘게 표시)
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    LOAD=$(printf "%.2f" "$(echo "$LOAD" | tr -d ',')")  # 소수점 둘째자리까지

    # 5. 증가량 계산
    if [ "$PREV_COUNT" -eq -1 ]; then
        DIFF="Start"
    else
        DIFF=$((CURRENT_COUNT - PREV_COUNT))
        [ "$DIFF" -gt 0 ] && DIFF="+$DIFF" || DIFF="$DIFF"
    fi

    # 6. 색상 강조 출력
    printf "%-21s | %-12s | \033[1;32m%-12s\033[0m | %-15s | \033[1;34m%-12s\033[0m | \033[1;33m%-12s\033[0m\n" \
        "$TIMESTAMP" "$CURRENT_COUNT" "$DIFF" "$MAX_HEIGHT" "$DB_SIZE" "$LOAD"

    PREV_COUNT=$CURRENT_COUNT
    sleep 7
done
