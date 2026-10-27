#!/bin/sh
# Start an MCP server that drives a Craft desktop app, opening the app with its control port first.
# For apps whose `<app>-cli mcp` can't open the app itself (CADCraft's `--launch` can).
# Usage: app-open.sh <App> <control option> <port> <token variable> <mcp server command...>
# (the control option and token variable are family.json's control and control_token_env; a token
# variable of - means the app keeps its own token)
# stdin and stdout carry the MCP client's messages, so nothing before the exec may touch them.
#
# Lineage:
#   run by   Claude Code, starting a live server that <app>:watch added (defined in servers.json)
#   runs     `open -a <App> [--env <token variable>=<fresh token>] --args <control option> <port>`,
#            then the MCP server command
set -e
app=$1 control=$2 port=$3 token_env=$4
shift 4
env=
if ! nc -z 127.0.0.1 "$port" </dev/null 2>/dev/null; then
  if pgrep -x "$app" </dev/null >/dev/null; then
    echo "$app is open without control port $port. Quit it so it can be reopened with one." >&2
    exit 1
  fi
  # An app that shares a token with its live server (FilmCraft) gets a fresh one for this session,
  # in the app's environment and in the server's, which inherits this script's.
  if [ "$token_env" != - ]; then
    token=$(openssl rand -hex 32)
    export "$token_env=$token"
    env="--env $token_env=$token"
  fi
  # shellcheck disable=SC2086
  open -a "$app" $env --args "$control" "$port" </dev/null >&2
  tries=0
  until nc -z 127.0.0.1 "$port" </dev/null 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 40 ]; then
      echo "$app did not open control port $port" >&2
      exit 1
    fi
    sleep 0.5
  done
elif [ "$token_env" != - ]; then
  echo "$app is open from an earlier session, and only that session has its token. Quit it so it can be reopened." >&2
  exit 1
fi
exec "$@"
