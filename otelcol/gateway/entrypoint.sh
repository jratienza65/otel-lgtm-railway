#!/bin/sh
# Picks the collector's authentication posture at startup.
#
# This has to happen here rather than in config.yaml: an env var can fill in a
# config *value*, but it cannot add or remove the basicauth extension and the
# receivers' auth blocks. otelcol deep-merges multiple --config sources, so the
# choice reduces to which files to pass.
#
# There is deliberately no implicit default. An unauthenticated OTLP endpoint on
# a public domain is a write path into the whole stack, and silently defaulting
# to open is how that happens by accident — so running open is allowed, but only
# when asked for by name.
#
# Only shell builtins are used below: busybox is copied in as a single binary
# with no applet symlinks, so `cat` and friends are not on PATH.
set -eu

BASE="--config=file:/etc/otelcol/config.yaml"
AUTH="--config=file:/etc/otelcol/auth.yaml"

if [ -n "${RAILWAY_OTEL_HTPASSWD:-}" ]; then
	exec /otelcol-contrib "$BASE" "$AUTH" "$@"
fi

if [ "${RAILWAY_OTEL_ALLOW_UNAUTHENTICATED:-}" = "true" ]; then
	echo "WARNING: OTLP ingest is UNAUTHENTICATED." >&2
	echo "WARNING: anyone who can reach this service can write telemetry into your stack." >&2
	echo "WARNING: set RAILWAY_OTEL_HTPASSWD to require credentials instead." >&2
	exec /otelcol-contrib "$BASE" "$@"
fi

echo "FATAL: refusing to start without an explicit authentication choice." >&2
echo "" >&2
echo "This service accepts OTLP writes. Set one of:" >&2
echo "" >&2
echo "  RAILWAY_OTEL_HTPASSWD=\"<user>:<password>\"" >&2
echo "      Require basic auth. One \"user:password\" line per producer." >&2
echo "      Plaintext works; so does a bcrypt hash from:" >&2
echo "          htpasswd -nbB <user> <password>" >&2
echo "" >&2
echo "  RAILWAY_OTEL_ALLOW_UNAUTHENTICATED=true" >&2
echo "      Run an open endpoint. Reasonable when the service has no public" >&2
echo "      domain and is only reachable over the private network." >&2
exit 1
