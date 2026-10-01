ARG VERSION=2.3.1

FROM grafana/pyroscope:${VERSION}

COPY ./config.yaml /etc/pyroscope/config.yaml

# Monolithic mode (the default target=all), persisting to the Railway volume at
# /data. Port 4040 serves both the HTTP query API that Grafana's pyroscope
# datasource reads and the OTLP profiles ingest the collector writes to; the gRPC
# port (9095) is internal component traffic, not an ingest path.
CMD [ "-config.file=/etc/pyroscope/config.yaml" ]
