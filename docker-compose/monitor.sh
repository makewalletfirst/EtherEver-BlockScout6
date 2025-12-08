#!/bin/bash

# docker-compose 파일 경로 설정
COMPOSE_FILE="/root/blockscout/docker-compose/docker-compose.yml"

# 초기화 변수
PREV_COUNT=-1

echo "=================================================================================="
echo " Starting Blockscout Sync Monitor (Update every 30s)"
echo "=================================================================================="
# 헤더 출력 (시간 | 현재 블록 수 | 증가량 | 최신 블록 높이)
printf "%-21s | %-15s | %-15s | %-15s\n" "Timestamp" "Total Count" "Increase" "Max Height"
echo "----------------------------------------------------------------------------------"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # 1. 현재 블록 총 개수 가져오기 (sa)
    # -T 옵션: 스크립트 내 실행 시 TTY 오류 방지
    # tr -d '[:space:]': 공백/줄바꿈 제거하여 숫자만 남김
    CURRENT_COUNT=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT count(*) FROM blocks;" | tr -d '[:space:]')

    # 2. 최신 블록 높이 가져오기 (saa)
    MAX_HEIGHT=$(docker compose -f "$COMPOSE_FILE" exec -T db psql -U blockscout -d blockscout -t -c "SELECT MAX(number) FROM blocks;" | tr -d '[:space:]')

    # DB 에러 등으로 값이 비었을 경우 처리
    if [ -z "$CURRENT_COUNT" ]; then CURRENT_COUNT=0; fi
    if [ -z "$MAX_HEIGHT" ]; then MAX_HEIGHT="N/A"; fi

    # 3. 증가량 계산
    if [ "$PREV_COUNT" -eq "-1" ]; then
        # 첫 실행 시에는 비교 대상이 없음
        DIFF="Start"
    else
        DIFF=$((CURRENT_COUNT - PREV_COUNT))
        # 양수면 앞에 + 붙여주기
        if [ "$DIFF" -ge 0 ]; then DIFF="+$DIFF"; fi
    fi

    # 4. 결과 출력 (한 줄에 출력)
    printf "%-21s | %-15s | \033[1;32m%-15s\033[0m | %-15s\n" "$TIMESTAMP" "$CURRENT_COUNT" "$DIFF" "$MAX_HEIGHT"

    # 현재 값을 이전 값으로 저장
    PREV_COUNT=$CURRENT_COUNT

    sleep 7
done
