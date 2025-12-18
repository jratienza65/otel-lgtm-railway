ARG VERSION=2.9.0

FROM grafana/tempo:${VERSION}

COPY ./config.yaml /etc/tempo/config.yaml

CMD [ "-config.file=/etc/tempo/config.yaml", \
      "-config.expand-env=true" ]

