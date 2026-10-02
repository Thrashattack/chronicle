#!/usr/bin/env bash
set -euo pipefail

wallet_url=${WALLET_URL:-http://localhost:3000}
news_url=${NEWS_URL:-http://localhost:3001}
animal_url=${ANIMAL_URL:-http://localhost:3002}
cross_store_url=${CROSS_STORE_URL:-http://localhost:3003}
cookie_dir=$(mktemp -d)
trap 'rm -rf "$cookie_dir"' EXIT

fetch_token() {
  local url=$1
  local cookie_file=$2
  curl --fail --silent --show-error --retry 10 --retry-all-errors --retry-delay 2 -b "$cookie_file" -c "$cookie_file" "$url" |
    ruby -e 'html = STDIN.read; token = html[/name="authenticity_token" value="([^"]+)"/, 1]; abort "CSRF token missing" unless token; puts token'
}

location_id() {
  local headers=$1
  local resource=$2
  printf '%s' "$headers" | ruby -e 'headers = STDIN.read; resource = ARGV.fetch(0); match = headers.match(%r{^location:.*?/#{Regexp.escape(resource)}/(\d+)}i); abort "redirect ID missing for #{resource}" unless match; puts match[1]' "$resource"
}

response_headers() {
  local cookie_file=$1
  local url=$2
  shift 2
  curl --fail --silent --show-error -b "$cookie_file" -c "$cookie_file" -D - -o /dev/null "$@" "$url"
}

check_get() {
  curl --fail --silent --show-error --retry 10 --retry-all-errors --retry-delay 2 "$1" -o /dev/null
  printf 'GET %s OK\n' "$1"
}

for url in "$wallet_url/" "$news_url/" "$animal_url/" "$cross_store_url/"; do
  check_get "$url"
done

wallet_cookie="$cookie_dir/wallet.cookies"
wallet_token=$(fetch_token "$wallet_url/wallets/new" "$wallet_cookie")
wallet_headers=$(response_headers "$wallet_cookie" "$wallet_url/wallets" \
  -X POST --data-urlencode "authenticity_token=$wallet_token" --data-urlencode 'wallet_account[name]=CI Smoke Wallet')
wallet_id=$(location_id "$wallet_headers" wallets)
check_get "$wallet_url/wallets/$wallet_id"

wallet_html=$(curl --fail --silent --show-error -b "$wallet_cookie" -c "$wallet_cookie" "$wallet_url/wallets/$wallet_id")
deposit_token=$(printf '%s' "$wallet_html" | ruby -e 'html = STDIN.read; form = html[/<form[^>]*action="[^"]*deposit".*?<\/form>/m]; token = form && form[/name="authenticity_token" value="([^"]+)"/, 1]; abort "deposit CSRF token missing" unless token; puts token')
response_headers "$wallet_cookie" "$wallet_url/wallets/$wallet_id/deposit" \
  -X POST --data-urlencode "authenticity_token=$deposit_token" --data-urlencode 'amount=10.00' --data-urlencode 'description=CI deposit' >/dev/null
wallet_html=$(curl --fail --silent --show-error -b "$wallet_cookie" -c "$wallet_cookie" "$wallet_url/wallets/$wallet_id")
withdraw_token=$(printf '%s' "$wallet_html" | ruby -e 'html = STDIN.read; form = html[/<form[^>]*action="[^"]*withdraw".*?<\/form>/m]; token = form && form[/name="authenticity_token" value="([^"]+)"/, 1]; abort "withdraw CSRF token missing" unless token; puts token')
response_headers "$wallet_cookie" "$wallet_url/wallets/$wallet_id/withdraw" \
  -X POST --data-urlencode "authenticity_token=$withdraw_token" --data-urlencode 'amount=1.00' --data-urlencode 'description=CI withdrawal' >/dev/null
check_get "$wallet_url/wallets/$wallet_id"

news_cookie="$cookie_dir/news.cookies"
news_token=$(fetch_token "$news_url/news_stories/new" "$news_cookie")
news_headers=$(response_headers "$news_cookie" "$news_url/news_stories" \
  -X POST --data-urlencode "authenticity_token=$news_token" \
  --data-urlencode 'news_story[headline]=CI Smoke Story' \
  --data-urlencode 'news_story[source]=CI' \
  --data-urlencode 'news_story[body]=Initial controller smoke-test revision')
news_id=$(location_id "$news_headers" news_stories)
news_html=$(curl --fail --silent --show-error -b "$news_cookie" -c "$news_cookie" "$news_url/news_stories/$news_id")
printf '%s' "$news_html" | grep -q 'Revision history'
printf '%s' "$news_html" | grep -q 'Initial controller smoke-test revision'
news_html=$(curl --fail --silent --show-error -b "$news_cookie" -c "$news_cookie" "$news_url/news_stories/$news_id/edit")
news_token=$(printf '%s' "$news_html" | ruby -e 'html = STDIN.read; token = html[/name="authenticity_token" value="([^"]+)"/, 1]; abort "news update CSRF token missing" unless token; puts token')
response_headers "$news_cookie" "$news_url/news_stories/$news_id" \
  -X POST --data-urlencode "authenticity_token=$news_token" --data-urlencode '_method=patch' \
  --data-urlencode 'news_story[headline]=CI Smoke Story Updated' \
  --data-urlencode 'news_story[source]=CI' \
  --data-urlencode 'news_story[body]=Updated controller smoke-test revision' >/dev/null
news_html=$(curl --fail --silent --show-error -b "$news_cookie" -c "$news_cookie" "$news_url/news_stories/$news_id")
printf '%s' "$news_html" | grep -q 'Initial controller smoke-test revision'
printf '%s' "$news_html" | grep -q 'Updated controller smoke-test revision'
check_get "$news_url/news_stories/$news_id/edit"
news_html=$(curl --fail --silent --show-error -b "$news_cookie" -c "$news_cookie" "$news_url/news_stories/$news_id/edit")
news_token=$(printf '%s' "$news_html" | ruby -e 'html = STDIN.read; token = html[/<meta name="csrf-token" content="([^"]+)"/, 1]; abort "news destroy CSRF token missing" unless token; puts token')
response_headers "$news_cookie" "$news_url/news_stories/$news_id" \
  -X POST --data-urlencode "authenticity_token=$news_token" --data-urlencode '_method=delete' >/dev/null
news_status=$(curl --silent --show-error -b "$news_cookie" -c "$news_cookie" -o /dev/null -w '%{http_code}' "$news_url/news_stories/$news_id")
[[ "$news_status" == 404 ]]

animal_cookie="$cookie_dir/animal.cookies"
animal_token=$(fetch_token "$animal_url/animals/new" "$animal_cookie")
animal_headers=$(response_headers "$animal_cookie" "$animal_url/animals" \
  -X POST --data-urlencode "authenticity_token=$animal_token" \
  --data-urlencode 'animal[name]=CI Smoke Fox' --data-urlencode 'animal[species]=Red fox')
animal_id=$(location_id "$animal_headers" animals)
check_get "$animal_url/animals/$animal_id"
animal_html=$(curl --fail --silent --show-error -b "$animal_cookie" -c "$animal_cookie" "$animal_url/animals/$animal_id")
location_token=$(printf '%s' "$animal_html" | ruby -e 'html = STDIN.read; form = html[/<form[^>]*action="[^"]*locations".*?<\/form>/m]; token = form && form[/name="authenticity_token" value="([^"]+)"/, 1]; abort "location CSRF token missing" unless token; puts token')
response_headers "$animal_cookie" "$animal_url/animals/$animal_id/locations" \
  -X POST --data-urlencode "authenticity_token=$location_token" \
  --data-urlencode 'animal_location[latitude]=37.7749' --data-urlencode 'animal_location[longitude]=-122.4194' >/dev/null
check_get "$animal_url/animals/$animal_id"

purchase_cookie="$cookie_dir/purchase.cookies"
purchase_html=$(curl --fail --silent --show-error -c "$purchase_cookie" "$cross_store_url/purchases/new")
purchase_token=$(printf '%s' "$purchase_html" | ruby -e 'html = STDIN.read; token = html[/name="authenticity_token" value="([^"]+)"/, 1]; abort "purchase CSRF token missing" unless token; puts token')
customer_id=$(printf '%s' "$purchase_html" | ruby -e 'html = STDIN.read; id = html.scan(/<option value="(\d+)"/).flatten.first; abort "Datomic customer option missing" unless id; puts id')
purchase_headers=$(response_headers "$purchase_cookie" "$cross_store_url/purchases" \
  -X POST --data-urlencode "authenticity_token=$purchase_token" \
  --data-urlencode "purchase[customer_id]=$customer_id" \
  --data-urlencode 'purchase[description]=CI smoke purchase' \
  --data-urlencode 'purchase[amount_cents]=1250')
printf '%s' "$purchase_headers" | grep -qi '^location:.*purchases'
check_get "$cross_store_url/purchases"
check_get "$cross_store_url/purchases/new"
for page in 1 2; do
  purchases_html=$(curl --fail --silent --show-error "$cross_store_url/purchases?page=$page")
  printf '%s' "$purchases_html" | ruby -e 'html = STDIN.read; page = ARGV.fetch(0); count = html.scan(/<article\b/).length; abort "page #{page} rendered #{count} purchases instead of 25" unless count == 25; abort "page #{page} indicator missing" unless html.include?("Page #{page} of")' "$page"
done
printf 'Purchase pagination OK (25 records per page)\n'