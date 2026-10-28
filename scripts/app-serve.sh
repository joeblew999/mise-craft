#!/usr/bin/env bash
# Lineage:
#   run by   Claude Code, as an app's one MCP server
#   runs     the app's headless server until Claude's first tool call; then scripts/app-open.sh,
#            which opens the app and starts its live server, and everything after goes there
#
# One MCP server per app that opens the app on Claude's first tool call, not when Claude Code starts
# the server (which it does for every server, at the start of every session). Until that call the
# headless server answers: the handshake and the tool list. The first tools/call switches to the
# live server, which gets the client's own handshake again under an id of ours (its answer is
# dropped), and Claude is told the tool list changed, since the live server can have more tools.
# Usage: app-serve.sh <App> <control option> <port> <token variable> <cli> <subcommand>
#                     <live options...> [-- <headless options...>]
# stdin and stdout carry the MCP messages.
set -e
app=$1 control=$2 port=$3 token_env=$4 cli=$5 sub=$6
shift 6
live=()
while [ $# -gt 0 ] && [ "$1" != -- ]; do live+=("$1"); shift; done
[ $# -gt 0 ] && shift
headless=("$@")
here=$(cd "$(dirname "$0")" && pwd)
pipe=$(mktemp -d)/in
mkfifo "$pipe"
trap 'exec 3>&-; rm -rf "$(dirname "$pipe")"' EXIT

# The headless server, its answers going straight to Claude.
"$cli" "$sub" ${headless[@]+"${headless[@]}"} <"$pipe" &
exec 3>"$pipe"
mode=headless
handshake=
while IFS= read -r line; do
  method=$(jq -r '.method // empty' <<<"$line" 2>/dev/null || true)
  [ "$method" = initialize ] && handshake=$line
  if [ "$mode" = headless ] && [ "$method" = tools/call ]; then
    exec 3>&-  # the headless server sees the end of its input and stops
    wait
    rm "$pipe"
    mkfifo "$pipe"
    sh "$here/app-open.sh" "$app" "$control" "$port" "$token_env" "$cli" "$sub" "${live[@]}" <"$pipe" \
      | jq -c --unbuffered -R 'fromjson? | select(.id != "app-serve")' &
    exec 3>"$pipe"
    jq -c '.id = "app-serve"' <<<"$handshake" >&3
    echo '{"jsonrpc":"2.0","method":"notifications/initialized"}' >&3
    echo '{"jsonrpc":"2.0","method":"notifications/tools/list_changed"}'
    mode=live
  fi
  printf '%s\n' "$line" >&3
done
exec 3>&-
wait
