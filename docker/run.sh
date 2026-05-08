#!/bin/sh

EEPROM_FILE="/opt/hamclock/.hamclock/eeprom"

# default size which only applies if all sizes are built
if [ -z "$HC_SIZE" ]; then
    HC_SIZE=2400x1440
fi

if [ -z "$BACKEND_HOST" -a -e /opt/hamclock/backend_host ]; then
    BACKEND_HOST="$(grep -v '^#' /opt/hamclock/backend_host)"
fi
if [ -n "$BACKEND_HOST" ]; then
    BACKEND_ARG_SET=1
fi

set_preseed_nv() {
    if [ -n "$2" ]; then
        perl hceeprom.pl "$1" "$2"
        return $?
    fi
    return 0
}

apply_preseed() {
    # Keep direct pulls fresh by default. Preseed only when a settings file exists
    # already, which is how the helper script stages first-run configuration.
    if [ ! -e "$EEPROM_FILE" ]; then
        return 0
    fi

    set_preseed_nv NV_CALLSIGN "$CALLSIGN" &&
    set_preseed_nv NV_DE_GRID "$LOCATOR" &&
    set_preseed_nv NV_DE_LAT "$LAT" &&
    set_preseed_nv NV_DE_LNG "$LONG" &&
    set_preseed_nv NV_BCMODE "$VOACAP_MODE" &&
    set_preseed_nv NV_BCPOWER "$VOACAP_POWER" &&
    set_preseed_nv NV_CALL_BG_COLOR "$CALLSIGN_BACKGROUND_COLOR" &&
    set_preseed_nv NV_CALL_BG_RAINBOW "$CALLSIGN_BACKGROUND_RAINBOW" &&
    set_preseed_nv NV_CALL_FG_COLOR "$CALLSIGN_COLOR" &&
    set_preseed_nv NV_FLRIGHOST "$FLRIG_HOST" &&
    set_preseed_nv NV_FLRIGPORT "$FLRIG_PORT" &&
    set_preseed_nv NV_FLRIGUSE "$USE_FLRIG" &&
    set_preseed_nv NV_METRIC_ON "$USE_METRIC"
}

apply_preseed || exit $?

# this extra work causes the container to stop quickly. We need to 
# kill our own jobs or bash will zombie and then docker takes 10 seconds
# before it sends kill -9. The wait will respond to a TERM whereas 
# tail does not so we need to background tail.
cleanup() {
    echo "Caught SIGTERM, shutting down services..."
    kill $(jobs -p)
    exit 0
}

# Trap the TERM signal
trap cleanup SIGTERM

if [ -x /opt/hamclock/bin/hamclock-web-$HC_SIZE ]; then
    HC_EXEC="/opt/hamclock/bin/hamclock-web-$HC_SIZE"
elif [ -x /opt/hamclock/bin/hamclock ]; then
    HC_EXEC="/opt/hamclock/bin/hamclock"
else
    echo "ERROR: no hamclock executable for size '$HC_SIZE'"
    exit 1
fi

set -- "$HC_EXEC"
if [ -n "$BACKEND_ARG_SET" ]; then
    set -- "$@" -b "$BACKEND_HOST"
fi

"$@" &
wait $!
