#!/bin/sh
# Requires an explicit choice about Faro ingest authentication.
#
# faro.receiver treats an empty api_key as "no key required", so an unset
# FARO_API_KEY silently produces a wide-open public write endpoint — anyone who
# finds the URL can flood your logs. That is a bad thing to arrive at by
# forgetting a variable, so it has to be asked for by name instead.
#
# The OTLP receiver is gated too, and unconditionally: those credentials belong
# to services rather than shipping inside a browser bundle, so there is no
# noise-filtering-only case for leaving them off. A deployment that wants
# unauthenticated OTLP should use otelcol/gateway, which supports it explicitly.
set -eu

if [ -z "${OTEL_INGEST_USERNAME:-}" ] || [ -z "${OTEL_INGEST_PASSWORD:-}" ]; then
	echo "FATAL: OTEL_INGEST_USERNAME and OTEL_INGEST_PASSWORD are required." >&2
	echo "" >&2
	echo "They protect the OTLP receiver on 4317/4318, which accepts writes into" >&2
	echo "every backend. Producers send: Authorization: Basic <base64 user:password>" >&2
	echo "" >&2
	echo "For unauthenticated OTLP ingest, use otelcol/gateway with" >&2
	echo "RAILWAY_OTEL_ALLOW_UNAUTHENTICATED=true instead." >&2
	exit 1
fi

if [ -n "${FARO_API_KEY:-}" ]; then
	exec /bin/alloy "$@"
fi

if [ "${FARO_ALLOW_UNAUTHENTICATED:-}" = "true" ]; then
	echo "WARNING: Faro ingest is UNAUTHENTICATED." >&2
	echo "WARNING: anyone who can reach this service can write telemetry into your stack." >&2
	echo "WARNING: set FARO_API_KEY to require a key instead." >&2
	exec /bin/alloy "$@"
fi

cat >&2 <<'MSG'
FATAL: refusing to start without an explicit authentication choice.

This service accepts telemetry writes from browsers. Set one of:

  FARO_API_KEY="<key>"
      Require clients to send it as the x-api-key header. The key ships
      inside app bundles, so it filters noise rather than authenticating —
      the rate limit, the payload cap and the CORS allowlist are the real
      controls. Still, an endpoint with no key at all is open to everyone.

  FARO_ALLOW_UNAUTHENTICATED=true
      Run an open endpoint. Reasonable when the service has no public
      domain and is only reachable over the private network.
MSG
exit 1
