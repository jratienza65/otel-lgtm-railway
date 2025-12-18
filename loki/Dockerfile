ARG VERSION=3.6.2

FROM grafana/loki:${VERSION}

COPY ./config.yaml /etc/loki/config.yaml

CMD ["-config.file=/etc/loki/config.yaml"]

