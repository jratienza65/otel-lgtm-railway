ARG VERSION=v1.18.1

# Grafana Alloy, not the OTel Collector: the Faro Web SDK posts its own JSON
# payload rather than OTLP, and `faro.receiver` is the only component that
# accepts it. Nothing in otelcol can serve /collect.
FROM grafana/alloy:${VERSION}

COPY ./config.alloy /etc/alloy/config.alloy
COPY ./config-direct.alloy /etc/alloy/config-direct.alloy
COPY ./entrypoint.sh /entrypoint.sh

# --server.http.listen-addr is Alloy's own UI/metrics port and stays private;
# Railway routes the public domain to the faro.receiver port (12347) instead.
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]

# No config path here — entrypoint.sh appends the one it selects.
CMD ["run", "--server.http.listen-addr=0.0.0.0:12345", "--storage.path=/var/lib/alloy/data"]
