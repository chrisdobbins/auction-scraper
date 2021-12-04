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
# time constants
# some have the unit preceding the number to
# prevent the base from changing
let H_48=172800
let H_24=86400
let H_16=57600
let H_12=43200
let H_4=14400
let H_2=7200
let H_1=3600
let HALF_H=1800
let QTR_H=900
let M_7PT5=450
let M_3PT75=225
let M_1PT875=113 # actually 112.5, but I'm assuming that rounding is sufficient
if [[ ${token_last_updated} > $H_48 ]]; then

    # deleting the newline is needed in order to get a valid response
    login_content_length=$(echo $(echo '{"userName":"'${USER_NAME}'","password":"'$PW'","remember":false,"clientIpAddress":"'$CLIENT_IP'","browser":"safari"}' | tr -d '\n' | wc -c)) 

    # login
    curl -s 'https://buyerapi.shopgoodwill.com/api/SignIn/Login' -X 'POST' -H 'Content-Type: application/json' -H 'Access-Control-Allow-Origin: *' -H 'Accept: application/json' -H 'Accept-Language: en-us' -H 'Accept-Encoding: gzip, deflate, br' -H 'Host: buyerapi.shopgoodwill.com' -H 'Access-Control-Allow-Credentials: true' -H 'Origin: https://shopgoodwill.com' -H 'Connection: keep-alive' -H 'User-Agent: '${USER_AGENT} -H 'Referer: https://shopgoodwill.com/signin' -H 'Content-Length:'${login_content_length}  --data-binary '{"userName":"'${USER_NAME}'","password":"'$PW'","remember":false,"clientIpAddress":"'$CLIENT_IP'","browser":"safari"}' | jq .accessToken > token.txt
fi

token=$(cat token.txt | tr -d '"')
top_bid=0
# get initial info
response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID} \
-X "GET" \
-H "Content-Type: application/json" \
-H "Access-Control-Allow-Origin: *" \
-H "Accept: application/json" \
-H "Authorization: Bearer ${token}" \
-H "Accept-Language: en-us" \
-H "Accept-Encoding: gzip, deflate, br" \
-H "Host: buyerapi.shopgoodwill.com" \
-H "Access-Control-Allow-Credentials: true" \
-H "Origin: https://shopgoodwill.com" \
-H "Connection: keep-alive" \
-H 'User-Agent: '${USER_AGENT} \
-H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))
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
bid_increment=$(echo $(echo $response | jq .bidIncrement | tr -d '"'))
bid_to_beat=$(echo "scale=2; ${top_bid}+${bid_increment}" | bc -l)
is_bid_enough=$(echo "scale=2; ${max_bid}>=${bid_to_beat}" | bc -l)
title=$(echo $(echo $response | jq .description | sed -E 's/<[a-z]{1,3}>Title: ([0-9a-z]+)<\/[a-z]{1,3}>/\1/g;s/(Item Attributes|Functionality|Condition).*//g'))

echo "Title: "${title}
echo "Top bid: "${top_bid}
echo 'Time left in auction: '$(echo "scale=2;"${local_time_left}"/3600" | bc -l)'h'

while [[ $is_bid_enough -eq 1 ]]; do
    now=$(date "+%s")
    let elapsed_time=now-timer
    if [[ $local_time_left -ge $H_24 ]]; then
        let polling_interval=${H_12}
    elif [[ $local_time_left -ge $H_12 ]]; then
        let polling_interval=${H_8}
    elif [[ $local_time_left -ge $H_8 ]]; then
        let polling_interval=${H_4}
    elif [[ $local_time_left -ge $H_4 ]]; then
        let polling_interval=${H_2}
    elif [[ $local_time_left -ge $H_2 ]]; then
        let polling_interval=${H_1}
    elif [[ $local_time_left -ge $H_1 ]]; then
        let polling_interval=${HALF_H}
    elif [[ $local_time_left -ge $HALF_H ]]; then
        let polling_interval=${QTR_H}
    elif [[ $local_time_left -ge $QTR_H ]]; then
        let polling_interval=${M_7PT5}
    elif [[ $local_time_left -ge $M_7PT5 ]]; then
        let polling_interval=${M_3PT75}
    elif [[ $local_time_left -ge $M_3PT75 ]]; then
        let polling_interval=${M_1PT875}
    elif [[ $local_time_left -ge $M_1PT875 ]]; then
        let polling_interval=75
    else
        let polling_interval=60
    fi
    if [[ $elapsed_time -ge $polling_interval ]]; then
        # get info about an auction
        response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID}  -X "GET" -H "Content-Type: application/json" -H "Access-Control-Allow-Origin: *" -H "Accept: application/json" -H "Authorization: Bearer ${token}" -H "Accept-Language: en-us" -H "Accept-Encoding: gzip, deflate, br" -H "Host: buyerapi.shopgoodwill.com" -H "Access-Control-Allow-Credentials: true" -H "Origin: https://shopgoodwill.com" -H "Connection: keep-alive" -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36' -H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))
        winning_bidder=$(echo $(echo $response | jq .bidHistory.bidSummary[0].buyerId | tr -d '"'))
        top_bid=$(echo $(echo $response | jq .bidHistory.bidSummary[0].amount | tr -d '"'))
        end_time=$(gdate --date=$(echo $response | jq .endTime | tr -d '"')"PST" "+%s")
        seller_id=$(echo $(echo $response | jq .sellerId | tr -d '"'))

        # server time format: "2021-11-28T21:17:45.34"
        # must add TZ to end of string instead of setting TZ env var
        server_time=$(gdate --date=$(echo $response | jq .serverTime | tr -d '"')"PST" "+%s")
        now=$(date "+%s")
        let time_left=end_time-server_time
        let offset=now-server_time
        let time_with_offset=$(date "+%s")+offset
        let local_time_left=end_time-time_with_offset
        timer=$(date "+%s")
        let bid_to_beat=$(echo "scale=2; ${top_bid}+${bid_increment}" | bc -l)

        echo 'Time left in auction: '$(echo "scale=2;"${local_time_left}"/3600" | bc -l)'h'
        echo "End time:" $end_time
        echo "Top bid: "$top_bid
        echo "Title: "${title}
        sleep .9 # This is to prevent flooding the screen
    fi

    let time_with_offset=$(date "+%s")+offset
    let local_time_left=end_time-time_with_offset
    
    should_poll_more_1=$(echo "${time_left} <= 5" | bc -l)
    should_poll_more_2=$(echo "${local_time_left} <= 5" | bc -l)

    while [[ ($should_poll_more_1 -eq 1) || ($should_poll_more_2 -eq 1) ]]; do
        response=$(echo $(curl -s 'https://buyerapi.shopgoodwill.com/api/ItemDetail/GetItemDetailModelByItemId/'${ITEM_ID} \
        -X "GET" \
        -H "Content-Type: application/json" \
        -H "Access-Control-Allow-Origin: *" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${token}" \
        -H "Accept-Language: en-us" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -H "Host: buyerapi.shopgoodwill.com" \
        -H "Access-Control-Allow-Credentials: true" \
        -H "Origin: https://shopgoodwill.com" \
        -H "Connection: keep-alive" \
        -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15' \
        -H "Referer: https://shopgoodwill.com/shopgoodwill/inprogress-auctions"))

        winning_bidder=$(echo $(echo $response | jq .bidHistory.bidSummary[0].buyerId | tr -d '"'))
        top_bid=$(echo $(echo $response | jq .bidHistory.bidSummary[0].amount | tr -d '"'))
        server_time=$(gdate --date=$(echo $response | jq .serverTime | tr -d '"')"PST" "+%s")
        end_time=$(gdate --date=$(echo $response | jq .endTime | tr -d '"')"PST" "+%s")
        let time_left=end_time-server_time
        let time_with_offset=$(date "+%s")+offset
        let local_time_left=end_time-time_with_offset
        let bid_to_beat=$(echo "scale=2; ${top_bid}+${bid_increment}" | bc -l)
        echo "time left: "$local_time_left

        # first condition is a reality check to see if 
        # the response is valid before placing a bid
        if [[ (${time_left} -gt 0 && ${local_time_left} -gt 0) && (${time_left} -le 3 ||  ${local_time_left} -le 3) ]]; then
            should_bid=$(echo "scale=2; ${max_bid}>=${top_bid}+${bid_increment}" | bc -l)
            echo $should_bid
            # it is _un_necessary to delete the newline;
            # in fact, doing so would lead to an invalid
            # response
            content_length=$(echo $(echo '{"itemId":"'$ITEM_ID',"quantity":1,"sellerId":'${seller_id}',"bidAmount":'${max_bid}'}' | wc -c)) 
            if  [[ ${winning_bidder} != ${USER_ID} && ${should_bid} -eq 1 ]]; then
                echo "Party time!"
                curl -s "https://buyerapi.shopgoodwill.com/api/ItemBid/PlaceBid" -X "POST" -H 'Content-Type: application/json' -H 'Access-Control-Allow-Origin: *' -H 'Accept: application/json' -H 'Authorization: Bearer '${token} -H 'Accept-Language: en-us' -H 'Accept-Encoding: gzip, deflate, br' -H 'Host: buyerapi.shopgoodwill.com' -H 'Access-Control-Allow-Credentials: true' -H 'Origin: https://shopgoodwill.com' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15' -H 'Referer: https://shopgoodwill.com/' -H 'Connection: keep-alive' -H 'Content-Length:'${content_length} --data-binary '{"itemId":'$ITEM_ID',"quantity":1,"sellerId":'${seller_id}',"bidAmount":"'${max_bid}'"}'
            fi
        elif [[ ${time_left} -le 0 || ${local_time_left} -le 0 ]]; then
            echo "auction is over!"
            exit 0
        fi
        sleep .45
    done
done

# if we've gotten here, it's because the bid was too low
echo "Bid too low! Current minimum bid to win is: "${bid_to_beat}
