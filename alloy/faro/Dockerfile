ARG VERSION=v1.18.1

# Grafana Alloy, not the OTel Collector: the Faro Web SDK posts its own JSON
# payload rather than OTLP, and `faro.receiver` is the only component that
# accepts it. Nothing in otelcol can serve /collect.
FROM grafana/alloy:${VERSION}

COPY ./config.alloy /etc/alloy/config.alloy

# --server.http.listen-addr is Alloy's own UI/metrics port and stays private;
# Railway routes the public domain to the faro.receiver port (12347) instead.
CMD ["run", "--server.http.listen-addr=0.0.0.0:12345", "--storage.path=/var/lib/alloy/data", "/etc/alloy/config.alloy"]
