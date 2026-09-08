ARG VERSION=0.139.0

# contrib distribution: the transform (OTTL) processor used by
# transform/preserve_prom_meta_identity ships in contrib only — the base image
# fails to start with `unknown type: "transform"`. (The resource processor is
# in the base image; transform is the one that forces contrib here.)
FROM otel/opentelemetry-collector-contrib:${VERSION}

COPY ./config.yaml /etc/otelcol/config.yaml

CMD ["--config=file:/etc/otelcol/config.yaml"]
