ARG VERSION=v3.8.0

FROM prom/prometheus:${VERSION}

COPY ./config.yaml /etc/prometheus/config.yaml

CMD [ "--web.enable-remote-write-receiver", \
      "--web.enable-otlp-receiver", \
      "--enable-feature=exemplar-storage", \
      "--storage.tsdb.path=/data/prometheus", \
      "--config.file=/etc/prometheus/config.yaml" ]

