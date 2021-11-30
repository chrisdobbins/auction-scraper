#!/bin/bash

. .credentials
ITEM_ID="$1"
token_last_updated=$(echo "$(date +%s) - $(date -r token.txt +%s)" | bc -l)
if [[ ! -n "$2" ]]; then
    echo "Must provide a max bid value"
    exit 1
fi
max_bid=$2
echo $max_bid

# 24h = 86400s
if [[ ${token_last_updated} > 172800 ]]; then

    # login
    curl -s 'https://buyerapi.shopgoodwill.com/api/SignIn/Login' -X 'POST' -H 'Content-Type: application/json' -H 'Access-Control-Allow-Origin: *' -H 'Accept: application/json' -H 'Accept-Language: en-us' -H 'Accept-Encoding: gzip, deflate, br' -H 'Host: buyerapi.shopgoodwill.com' -H 'Access-Control-Allow-Credentials: true' -H 'Origin: https://shopgoodwill.com' -H 'Connection: keep-alive' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15' -H 'Referer: https://shopgoodwill.com/signin' -H 'Content-Length: 128' --data-binary '{"userName":"'${USER_NAME}'","password":"'$PW'","remember":false,"clientIpAddress":"'$CLIENT_IP'","browser":"safari"}' | jq .accessToken > token.txt


fi

token=$(cat token.txt | tr -d '"')
while [[ 1=1 ]]; do

    # get info about an auction
    response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID}  -X "GET" -H "Content-Type: application/json" -H "Access-Control-Allow-Origin: *" -H "Accept: application/json" -H "Authorization: Bearer ${token}" -H "Accept-Language: en-us" -H "Accept-Encoding: gzip, deflate, br" -H "Host: buyerapi.shopgoodwill.com" -H "Access-Control-Allow-Credentials: true" -H "Origin: https://shopgoodwill.com" -H "Connection: keep-alive" -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15' -H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))

    winning_bidder=$(echo $(echo $response | jq .bidHistory.bidSummary[0].buyerId | tr -d '"'))
    top_bid=$(echo $(echo $response | jq .bidHistory.bidSummary[0].amount | tr -d '"'))
    end_time=$(TZ='America/Los_Angeles'; gdate --date=$(echo $response | jq .endTime | tr -d '"') "+%s")
    seller_id=$(echo $(echo $response | jq .sellerId | tr -d '"'))



    # server time format: "2021-11-28T21:17:45.34"
    server_time=$(TZ='America/Los_Angeles'; gdate --date=$(echo $response | jq .serverTime | tr -d '"') "+%s")
    now=$(date "+%s")
    let time_left=end_time-server_time
    let offset=now-server_time

    echo "server time: " $server_time
    echo "now: "$now
    echo "end time:" $end_time
    echo "offset: "${offset}
    echo "time left in auction: "$time_left
    echo "winning bidder: "$winning_bidder
    echo "top bid: "$top_bid

    should_poll_more=$(echo "${time_left} < 30" | bc -l)

    while [[ $should_poll_more -eq 1 ]]; do
        response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID}  -X "GET" -H "Content-Type: application/json" -H "Access-Control-Allow-Origin: *" -H "Accept: application/json" -H "Authorization: Bearer ${token}" -H "Accept-Language: en-us" -H "Accept-Encoding: gzip, deflate, br" -H "Host: buyerapi.shopgoodwill.com" -H "Access-Control-Allow-Credentials: true" -H "Origin: https://shopgoodwill.com" -H "Connection: keep-alive" -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15" -H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))
    
        winning_bidder=$(echo $(echo $response | jq .bidHistory.bidSummary[0].buyerId | tr -d '"'))
        top_bid=$(echo $(echo $response | jq .bidHistory.bidSummary[0].amount | tr -d '"'))
        server_time=$(TZ='America/Los_Angeles'; gdate --date=$(echo $response | jq .serverTime | tr -d '"') "+%s")
        end_time=$(TZ='America/Los_Angeles'; gdate --date=$(echo $response | jq .endTime | tr -d '"') "+%s")
        let time_left=end_time-server_time
        echo "time left: "$time_left


    if [[ 0 -eq 1 ]]; then #${time_left} -le 7 ]]; then
        should_bid="echo 'scale=2; ${max_bid}<=${top_bid}'" | bc -l 
        echo $should_bid
        if  [[ ${winning_bidder} == "null"  || (${winning_bidder} != ${me} && ${should_bid} -eq 1) ]]; then
            curl -s "https://buyerapi.shopgoodwill.com/api/ItemBid/PlaceBid" -X "POST"\
            -H "Content-Type: application/json"\ 
            -H "Access-Control-Allow-Origin: *"\
            -H "Accept: application/json"\
            -H "Authorization: Bearer ${token}"\
            -H "Accept-Language: en-us"\
            -H "Accept-Encoding: gzip, deflate, br"\
            -H "Host: buyerapi.shopgoodwill.com"\
            -H "Access-Control-Allow-Credentials: true"\
            -H "Origin: https://shopgoodwill.com"\
            -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15"\
            -H "Referer: https://shopgoodwill.com/"\
            -H "Connection: keep-alive"\
            --data-binary "{\"itemId\":\"$ITEM_ID\",\"quantity\":1,\"sellerId\":${seller_id},\"bidAmount\":\"${max_bid}\"}"
        fi
    fi
        sleep 2
    done
    sleep 600
done
