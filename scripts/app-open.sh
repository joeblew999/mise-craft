#!/bin/sh
# Start an MCP server that drives a Craft desktop app, opening the app with its control port first.
# For apps whose `<app>-cli mcp` can't open the app itself (CADCraft's `--launch` can).
# Usage: app-open.sh <App> <control option> <port> <mcp server command...>
# (the control option is family.json's control, such as --control)
# stdin and stdout carry the MCP client's messages, so nothing before the exec may touch them.
#
# Lineage:
#   run by   Claude Code, starting a live server that <app>:watch added (defined in servers.json)
#   runs     `open -a <App> --args <control option> <port>`, then the MCP server command
set -e
app=$1 control=$2 port=$3
shift 3
if ! nc -z 127.0.0.1 "$port" </dev/null 2>/dev/null; then
  if pgrep -x "$app" </dev/null >/dev/null; then
    echo "$app is open without control port $port. Quit it so it can be reopened with one." >&2
    exit 1
  fi
  open -a "$app" --args "$control" "$port" </dev/null >&2
  tries=0
  until nc -z 127.0.0.1 "$port" </dev/null 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 40 ]; then
      echo "$app did not open control port $port" >&2
      exit 1
    fi
    sleep 0.5
  done
fi
exec "$@"
