ARG VERSION=v1.18.1

# Alloy embeds the collector's own receivers, processors and exporters, so it
# can serve as the gateway on its own: `faro.receiver` for browser/mobile RUM
# (which no otelcol build can accept) plus `otelcol.receiver.otlp` for app SDKs,
# writing straight to Loki/Tempo/Prometheus.
FROM grafana/alloy:${VERSION}

COPY ./config.alloy /etc/alloy/config.alloy
COPY ./entrypoint.sh /entrypoint.sh

# --server.http.listen-addr is Alloy's own UI/metrics port and stays private.
# Railway routes the public domain to the faro.receiver port (12347); OTLP is
# on 4317/4318 for sibling services on the private network.
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]

CMD ["run", "--server.http.listen-addr=0.0.0.0:12345", "--storage.path=/var/lib/alloy/data", "/etc/alloy/config.alloy"]
