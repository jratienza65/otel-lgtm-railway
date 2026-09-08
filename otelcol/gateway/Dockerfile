ARG VERSION=0.139.0

# Static shell for entrypoint.sh. The collector image is distroless — no shell,
# no coreutils — so the startup auth decision needs one copied in. busybox is
# invoked explicitly rather than via /bin/sh, so no symlink is required.
FROM busybox:1.37.0-uclibc AS busybox

# contrib distribution: the basicauth extension used by auth.yaml ships in
# contrib, not in the base collector image, which fails to start with
# `unknown type: "basicauth"`.
FROM otel/opentelemetry-collector-contrib:${VERSION}

COPY --from=busybox /bin/busybox /bin/busybox

COPY ./config.yaml /etc/otelcol/config.yaml
COPY ./auth.yaml /etc/otelcol/auth.yaml
COPY ./entrypoint.sh /entrypoint.sh

# Passed to busybox sh as an argument, so entrypoint.sh needs to be readable
# but not executable — which keeps this working regardless of the checkout's
# file mode.
ENTRYPOINT ["/bin/busybox", "sh", "/entrypoint.sh"]
