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
timer=$(date "+%s")
# 24h = 86400s
if [[ ${token_last_updated} > 172800 ]]; then

    # login
    curl -s 'https://buyerapi.shopgoodwill.com/api/SignIn/Login' -X 'POST' -H 'Content-Type: application/json' -H 'Access-Control-Allow-Origin: *' -H 'Accept: application/json' -H 'Accept-Language: en-us' -H 'Accept-Encoding: gzip, deflate, br' -H 'Host: buyerapi.shopgoodwill.com' -H 'Access-Control-Allow-Credentials: true' -H 'Origin: https://shopgoodwill.com' -H 'Connection: keep-alive' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15' -H 'Referer: https://shopgoodwill.com/signin' -H 'Content-Length: 128' --data-binary '{"userName":"'${USER_NAME}'","password":"'$PW'","remember":false,"clientIpAddress":"'$CLIENT_IP'","browser":"safari"}' | jq .accessToken > token.txt
fi

token=$(cat token.txt | tr -d '"')
top_bid=0
# get initial info
response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID}  -X "GET" -H "Content-Type: application/json" -H "Access-Control-Allow-Origin: *" -H "Accept: application/json" -H "Authorization: Bearer ${token}" -H "Accept-Language: en-us" -H "Accept-Encoding: gzip, deflate, br" -H "Host: buyerapi.shopgoodwill.com" -H "Access-Control-Allow-Credentials: true" -H "Origin: https://shopgoodwill.com" -H "Connection: keep-alive" -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15' -H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))
end_time=$(gdate --date=$(echo $response | jq .endTime | tr -d '"')"PST" "+%s")
server_time=$(gdate --date=$(echo $response | jq .serverTime | tr -d '"')"PST" "+%s")
let time_left=end_time-server_time
now=$(date "+%s")
let offset=now-server_time
let time_with_offset=$(date "+%s")+offset
let local_time_left=end_time-time_with_offset
winning_bidder=$(echo $(echo $response | jq .bidHistory.bidSummary[0].buyerId | tr -d '"'))
top_bid=$(echo $(echo $response | jq .bidHistory.bidSummary[0].amount | tr -d '"'))
seller_id=$(echo $(echo $response | jq .sellerId | tr -d '"'))


while [[ max_bid -gt top_bid ]]; do
    now=$(date "+%s")
    let elapsed_time=now-timer
    if [[ $elapsed_time -ge 6000 ]]; then
        # get info about an auction
        response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID}  -X "GET" -H "Content-Type: application/json" -H "Access-Control-Allow-Origin: *" -H "Accept: application/json" -H "Authorization: Bearer ${token}" -H "Accept-Language: en-us" -H "Accept-Encoding: gzip, deflate, br" -H "Host: buyerapi.shopgoodwill.com" -H "Access-Control-Allow-Credentials: true" -H "Origin: https://shopgoodwill.com" -H "Connection: keep-alive" -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15' -H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))
        timer=$(date "+%s")
        winning_bidder=$(echo $(echo $response | jq .bidHistory.bidSummary[0].buyerId | tr -d '"'))
        top_bid=$(echo $(echo $response | jq .bidHistory.bidSummary[0].amount | tr -d '"'))
        end_time=$(gdate --date=$(echo $response | jq .endTime | tr -d '"')"PST" "+%s")
        seller_id=$(echo $(echo $response | jq .sellerId | tr -d '"'))

        # server time format: "2021-11-28T21:17:45.34"
        # must add TZ to end of string since setting TZ
        # is somehow not working
        server_time=$(gdate --date=$(echo $response | jq .serverTime | tr -d '"')"PST" "+%s")
        now=$(date "+%s")
        let time_left=end_time-server_time
        let offset=now-server_time
        let time_with_offset=$(date "+%s")+offset
        let local_time_left=end_time-time_with_offset
#        echo "end time:" $end_time
#        echo "winning bidder: "$winning_bidder
#        echo "top bid: "$top_bid
   fi

    let time_with_offset=$(date "+%s")+offset
    let local_time_left=end_time-time_with_offset
    should_print=$(expr $elapsed_time % 30)
    
    if [[ should_print -eq 0 ]]; then
        echo "time left in auction: "$local_time_left
        echo "end time:" $end_time
        echo "winning bidder: "$winning_bidder
        echo "top bid: "$top_bid
    fi
    # increase polling rate when there are 15min or fewer
    # left in the auction
    should_poll_more_1=$(echo "${time_left} <= 900" | bc -l)
    should_poll_more_2=$(echo "${local_time_left} <= 900" | bc -l)

    while [[ ($should_poll_more_1 -eq 1) || ($should_poll_more_2 -eq 1) ]]; do
        response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID}  -X "GET" -H "Content-Type: application/json" -H "Access-Control-Allow-Origin: *" -H "Accept: application/json" -H "Authorization: Bearer ${token}" -H "Accept-Language: en-us" -H "Accept-Encoding: gzip, deflate, br" -H "Host: buyerapi.shopgoodwill.com" -H "Access-Control-Allow-Credentials: true" -H "Origin: https://shopgoodwill.com" -H "Connection: keep-alive" -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15" -H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))

        winning_bidder=$(echo $(echo $response | jq .bidHistory.bidSummary[0].buyerId | tr -d '"'))
        top_bid=$(echo $(echo $response | jq .bidHistory.bidSummary[0].amount | tr -d '"'))
        server_time=$(gdate --date=$(echo $response | jq .serverTime | tr -d '"')"PST" "+%s")
        end_time=$(gdate --date=$(echo $response | jq .endTime | tr -d '"')"PST" "+%s")
        let time_left=end_time-server_time
        let time_with_offset=$(date "+%s")+offset
        let local_time_left=end_time-time_with_offset
        echo "time left: "$local_time_left

        # first condition is a reality check to see if 
        # the response is valid before placing a bid
        if [[ (${time_left} -gt 0) && ((${time_left} -le 5) ||  ${local_time_left} -le 5) ]]; then
            should_bid="echo 'scale=2; ${max_bid}<${top_bid}'" | bc -l 
            if  [[ ${winning_bidder} != ${USER_ID} && ${should_bid} -eq 1 ]]; then
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
done
