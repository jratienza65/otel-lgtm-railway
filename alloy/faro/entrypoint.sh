#!/bin/sh
# Requires an explicit choice about Faro ingest authentication.
#
# faro.receiver treats an empty api_key as "no key required", so an unset
# FARO_API_KEY silently produces a wide-open public write endpoint — anyone who
# finds the URL can flood your logs. That is a bad thing to arrive at by
# forgetting a variable, so it has to be asked for by name instead.
#
# It also picks the destination. Alloy's config language has no conditionals, so
# forwarding to a gateway and writing straight to the backends are two files and
# the choice is which one to run:
#
#   OTEL_EXPORTER_OTLP_ENDPOINT set  -> config.alloy, forward to that gateway
#   RAILWAY_LOKI + TEMPO_ENDPOINT    -> config-direct.alloy, write to the backends
#
# The direct path needs no collector at all. It still needs the backends: Tempo
# refuses to start without a Prometheus to remote-write span metrics to.
set -eu

CFG=""
if [ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]; then
	CFG=/etc/alloy/config.alloy
elif [ -n "${RAILWAY_LOKI_ENDPOINT:-}" ] && [ -n "${RAILWAY_TEMPO_ENDPOINT:-}" ]; then
	CFG=/etc/alloy/config-direct.alloy
else
	echo "FATAL: refusing to start without a destination." >&2
	echo "" >&2
	echo "This service receives browser telemetry. Set one of:" >&2
	echo "" >&2
	echo "  OTEL_EXPORTER_OTLP_ENDPOINT=<gateway>" >&2
	echo "      Forward everything to an OTLP gateway, which owns the writes." >&2
	echo "      Pair with OTEL_UPSTREAM_USERNAME / OTEL_UPSTREAM_PASSWORD." >&2
	echo "" >&2
	echo "  RAILWAY_LOKI_ENDPOINT=<loki>/otlp  and  RAILWAY_TEMPO_ENDPOINT=<tempo>:4318" >&2
	echo "      Write straight to the backends, with no collector in the path." >&2
	exit 1
fi

# The Dockerfile's CMD carries the flags but not the config path, so the chosen
# config is simply appended.
run_alloy() { exec /bin/alloy "$@" "$CFG"; }

if [ -n "${FARO_API_KEY:-}" ]; then
	run_alloy "$@"
fi

if [ "${FARO_ALLOW_UNAUTHENTICATED:-}" = "true" ]; then
	echo "WARNING: Faro ingest is UNAUTHENTICATED." >&2
	echo "WARNING: anyone who can reach this service can write telemetry into your stack." >&2
	echo "WARNING: set FARO_API_KEY to require a key instead." >&2
	run_alloy "$@"
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
