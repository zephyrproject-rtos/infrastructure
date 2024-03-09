#/usr/bin/env bash

# Validate log type.
case "$1" in
  INFORMATION|INFO)
    logType="INFORMATION"
    logColor="1127128"
    ;;

  WARNING|WARN)
    logType="WARNING"
    logColor="16760576"
    ;;

  ERROR|ERR)
    logType="ERROR"
    logColor="16711680"
    ;;

  *)
    echo "ERROR: Invalid log type."
    exit
    ;;
esac
shift

# Print log messasge to stdout.
echo "${logType}: ${@}"

# Send log message to Discord channel.
if [ ! -z "${DISCORD_INFRA_MONITOR_WEBHOOK}" ]; then
  discordMessage='
  {
    "embeds": [
      {
        "title": "'"${logType}: ${@}"'",
	"color": "'"${logColor}"'"
      }
    ]
  }
  '

  curl \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${discordMessage}" \
    ${DISCORD_INFRA_MONITOR_WEBHOOK}
fi
