ARG VERSION=0.139.0

FROM otel/opentelemetry-collector:${VERSION}

COPY ./config.yaml /etc/otelcol/config.yaml

CMD ["--config=file:/etc/otelcol/config.yaml"]

