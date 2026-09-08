ARG VERSION=v3.8.0

FROM prom/prometheus:${VERSION}

COPY ./config.yaml /etc/prometheus/config.yaml

# Retention is bounded by BOTH time and size; whichever trips first wins.
# Prometheus does not know how big its volume is, so without the size bound a
# busy TSDB will fill the Railway volume and wedge the service. Keep
# retention.size comfortably below the provisioned volume (headroom for
# compaction, the WAL and head blocks) and raise both together as it grows.
CMD [ "--web.enable-remote-write-receiver", \
      "--web.enable-otlp-receiver", \
      "--enable-feature=exemplar-storage", \
      "--storage.tsdb.retention.time=90d", \
      "--storage.tsdb.retention.size=20GB", \
      "--storage.tsdb.path=/data/prometheus", \
      "--config.file=/etc/prometheus/config.yaml" ]
