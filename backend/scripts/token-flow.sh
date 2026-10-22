#!/usr/bin/env bash
# Hands-on exercise 19a: rotation, reuse detection, logout and logout-all.
# Prints only HTTP status codes and "different"/"same" - never token values.
# Uses node instead of jq to read JSON fields.
set -u

BASE=${BASE:-http://localhost:3000/api/v1}
EMAIL="student-$RANDOM$RANDOM@example.test"
PASSWORD='a-long-local-test-password-for-this-exercise'

json() { node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const v=JSON.parse(s)['$1'];process.stdout.write(v==null?'':String(v))})"; }
post() { curl -sS -X POST "$BASE/$1" -H 'Content-Type: application/json' -d "$2"; }
status() { curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE/$1" -H 'Content-Type: application/json' "${@:3}" -d "$2"; }
check() { if [ "$2" = "$3" ]; then r=PASS; else r=FAIL; fi; printf '| %-38s | %-8s | %-6s | %-4s |\n' "$1" "$3" "$2" "$r"; }

echo "Health: $(curl -sS http://localhost:3000/health)"

# Setup
REGISTER=$(post auth/register "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
ACCESS=$(printf '%s' "$REGISTER" | json accessToken)
REFRESH=$(printf '%s' "$REGISTER" | json refreshToken)
unset REGISTER
[ -n "$ACCESS" ] && [ -n "$REFRESH" ] && echo "Setup: both token variables are set (values not shown)"

echo
printf '| %-38s | %-8s | %-6s | %-4s |\n' "Test" "Expected" "Result" "Pass"
printf '|%s|%s|%s|%s|\n' "----------------------------------------" "----------" "--------" "------"

# Task 1 - Rotation
OLD_REFRESH=$REFRESH
ROTATED=$(curl -sS -w '\n%{http_code}' -X POST "$BASE/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$OLD_REFRESH\"}")
ROTATION_STATUS=$(printf '%s' "$ROTATED" | tail -n1)
ROTATED=$(printf '%s' "$ROTATED" | head -n1)
ACCESS=$(printf '%s' "$ROTATED" | json accessToken)
REFRESH=$(printf '%s' "$ROTATED" | json refreshToken)
unset ROTATED
check "Refresh with valid token" "$ROTATION_STATUS" 200
if [ "$REFRESH" != "$OLD_REFRESH" ]; then CMP=different; else CMP=same; fi
check "New refresh token differs from old" "$CMP" different

# Task 2 - Reuse detection
check "Refresh with old token" "$(status auth/refresh "{\"refreshToken\":\"$OLD_REFRESH\"}")" 401
check "Refresh with newest token after reuse" "$(status auth/refresh "{\"refreshToken\":\"$REFRESH\"}")" 401

# Task 3 - Logout
LOGIN=$(post auth/login "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
LOGOUT_REFRESH=$(printf '%s' "$LOGIN" | json refreshToken)
unset LOGIN
check "Logout" "$(status auth/logout "{\"refreshToken\":\"$LOGOUT_REFRESH\"}")" 204
check "Refresh after logout" "$(status auth/refresh "{\"refreshToken\":\"$LOGOUT_REFRESH\"}")" 401

# Task 4 - Logout-all
SESSION_ONE=$(post auth/login "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
ACCESS_ONE=$(printf '%s' "$SESSION_ONE" | json accessToken)
REFRESH_ONE=$(printf '%s' "$SESSION_ONE" | json refreshToken)
SESSION_TWO=$(post auth/login "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
REFRESH_TWO=$(printf '%s' "$SESSION_TWO" | json refreshToken)
unset SESSION_ONE SESSION_TWO
check "Logout-all" "$(status auth/logout-all '' -H "Authorization: Bearer $ACCESS_ONE")" 204
check "Refresh after logout-all (session 1)" "$(status auth/refresh "{\"refreshToken\":\"$REFRESH_ONE\"}")" 401
check "Refresh after logout-all (session 2)" "$(status auth/refresh "{\"refreshToken\":\"$REFRESH_TWO\"}")" 401

# Protected task routes
LOGIN=$(post auth/login "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
ACCESS=$(printf '%s' "$LOGIN" | json accessToken)
unset LOGIN
CREATE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE/tasks" -H "Authorization: Bearer $ACCESS" \
  -H 'Content-Type: application/json' -d '{"title":"Review API security","description":"Check ownership and validation"}')
check "Create task" "$CREATE" 201
check "List tasks" "$(curl -sS -o /dev/null -w "%{http_code}" "$BASE/tasks?page=1&limit=20" -H "Authorization: Bearer $ACCESS")" 200
check "List tasks without token" "$(curl -sS -o /dev/null -w "%{http_code}" "$BASE/tasks")" 401

unset ACCESS REFRESH OLD_REFRESH LOGOUT_REFRESH ACCESS_ONE REFRESH_ONE REFRESH_TWO
