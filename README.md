# otel-lgtm-railway

**otel-lgtm-railway** is a self-hosted [Grafana LGTM](https://grafana.com/oss/) observability stack
for [Railway](https://railway.com) — Loki for logs, Tempo for traces, Prometheus for metrics, Grafana
on top — fronted by either an [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) or
[Grafana Alloy](https://grafana.com/docs/alloy/latest/). Every directory here is one Railway service:
a `Dockerfile` pinning an upstream image, plus the config baked into it. There is no application
code.

## Why

Railway gives you a live log viewer and a metrics UI, but no place to send OTLP. If your services are
already instrumented with OpenTelemetry, the options are to pay a vendor or to stand up the backends
yourself — and standing them up means learning which Loki, Tempo and Prometheus knobs matter on a
single node with one volume, most of which only announce themselves after data starts being dropped.

This repo is that stack, pre-tuned, as deploy-ready services:

- **Retention that actually applies.** Loki's retention is inert without a compactor; Prometheus
  fills the volume without a size bound; Tempo needs real compaction settings or trace search decays.
- **Ingest sized for the backends.** Loki drops OTLP log batches over 4MB with a 503; the collector
  caps log batches to stay under it.
- **Correlation wired up.** Logs ↔ traces ↔ exemplars ↔ service graph, provisioned in Grafana rather
  than clicked together afterwards.
- **Frontend RUM included.** A [Faro](https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/)
  receiver and a 57-panel dashboard, for the browser half of the picture.
- **Auth that fails closed.** No service that accepts writes will start without an explicit decision
  about whether it requires credentials.

It pairs with [intermodal](https://github.com/jratienza65/intermodal) if you also want Railway's own
platform metrics and logs in the same stack — point its OTLP endpoint at the gateway.

## Quick start (deploy on Railway)

1. Pick a topology from the table below. You do not deploy every directory.

2. Create one Railway service per directory in that row, setting each service's **root directory** to
   the directory (`loki`, `otelcol/gateway`, …).

3. Attach volumes and set `RAILWAY_RUN_UID=0` on the services that have them — see
   [Volumes](#volumes).

4. Set service variables. The backends need nothing; the wiring lives on the gateway and Grafana:

   ```bash
   # On the collector gateway — where to write each signal. Note the OTLP paths.
   RAILWAY_LOKI_ENDPOINT=http://${{Loki.RAILWAY_PRIVATE_DOMAIN}}:3100/otlp
   RAILWAY_TEMPO_ENDPOINT=http://${{Tempo.RAILWAY_PRIVATE_DOMAIN}}:4318
   RAILWAY_PROMETHEUS_ENDPOINT=http://${{Prometheus.RAILWAY_PRIVATE_DOMAIN}}:9090/api/v1/otlp

   # Require credentials on ingest. One "user:password" line per producer.
   RAILWAY_OTEL_HTPASSWD=app:$(openssl rand -hex 16)

   # On Grafana — the SAME variable names, but base URLs, not OTLP paths.
   RAILWAY_LOKI_ENDPOINT=http://${{Loki.RAILWAY_PRIVATE_DOMAIN}}:3100
   RAILWAY_TEMPO_ENDPOINT=http://${{Tempo.RAILWAY_PRIVATE_DOMAIN}}:3200
   RAILWAY_PROMETHEUS_ENDPOINT=http://${{Prometheus.RAILWAY_PRIVATE_DOMAIN}}:9090

   # On Tempo — span metrics and service graphs are remote-written to Prometheus.
   RAILWAY_PROMETHEUS_REMOTE_WRITE_ENDPOINT=http://${{Prometheus.RAILWAY_PRIVATE_DOMAIN}}:9090/api/v1/write
   ```

5. Give the gateway and Grafana public domains — the gateway on port `4318` (or `12347` for an Alloy
   gateway), Grafana on `3000`. Everything else stays on the private network.

6. Point your SDKs at the gateway's domain with `Authorization: Basic <base64 user:password>`.

## Topologies

You do not deploy all of it. Pick the row that matches what you are doing.

| Topology | Deploy | Use when |
| --- | --- | --- |
| **Full stack, OTLP-first** | `otelcol/gateway` + `loki` `tempo` `prometheus` `grafana` | The common case. Your services emit OTLP and you want to own the backends. |
| **Full stack, RUM-first** | `alloy/gateway` + `loki` `tempo` `prometheus` `grafana` | Frontend RUM is why you are here. Alloy is the gateway; no otelcol at all. |
| **Full stack, both** | `otelcol/gateway` + `alloy/faro` + backends | OTLP-first, but you also want browser RUM. Alloy parses Faro and forwards to otelcol. |
| **Edge agent only** | `otelcol/agent` | One per app project. Forwards to a gateway that already exists elsewhere. No backends. |
| **RUM ingest only** | `alloy/faro` | Take browser RUM and forward it to an OTLP endpoint someone else runs. |

The two gateways are alternatives — deploy one or the other, never both. `otelcol/gateway` is the
conventional choice, and OTTL processors are easier to reason about in its YAML than in Alloy's
syntax. `alloy/gateway` exists because otelcol cannot accept the Faro Web SDK's payload at all, so a
RUM-first deployment would otherwise run Alloy *and* otelcol just to have otelcol relay what Alloy
already parsed.

## Services

| Directory | Image | Role |
| --- | --- | --- |
| `otelcol/gateway` | `otel/opentelemetry-collector-contrib` | Central OTLP hub. Authenticated ingest, writes to all three backends. |
| `otelcol/agent` | `otel/opentelemetry-collector-contrib` | Per-project edge collector. Stamps environment, forwards upstream. |
| `alloy/gateway` | `grafana/alloy` | Faro **and** OTLP receiver, writing straight to the backends. |
| `alloy/faro` | `grafana/alloy` | Faro receiver only, forwarding to a gateway. |
| `loki` | `grafana/loki` | Logs. Tiered retention, compaction enabled. |
| `tempo` | `grafana/tempo` | Traces. Compaction, span metrics, service graphs. |
| `prometheus` | `prom/prometheus` | Metrics. OTLP and remote-write receivers, bounded retention. |
| `grafana` | `grafana/grafana-oss` | Provisioned datasources, correlation wiring, dashboards. |

Ports: otelcol `4317` gRPC / `4318` HTTP, health on `13133/ready`; alloy `12347` for Faro (the port
Railway routes to) and `12345` for Alloy's own UI; loki `3100`; tempo `3200` HTTP, `9096` gRPC,
`7947` memberlist; prometheus `9090`; grafana `3000`.

## Volumes

Four services keep state; the rest are stateless.

| Service | Mount path | Holds |
| --- | --- | --- |
| `loki` | `/data` | Chunks, TSDB index, and the compactor's retention markers |
| `tempo` | `/data` | WAL, trace blocks, metrics-generator WAL |
| `prometheus` | `/data` | TSDB, WAL, head chunks |
| `grafana` | `/data/grafana` | SQLite DB — users, API keys, dashboards saved from the UI |

Set `RAILWAY_RUN_UID=0` on each. These images run as a non-root user and the mounted volume is owned
by root, so without it the service cannot write to its own storage. Grafana also needs
`GF_PATHS_DATA=/data/grafana` to match the mount.

> ⚠️ **Warning**: keep Loki's `compactor.working_directory` under `/data`.
>
> It holds the retention deletion markers. The compactor marks chunks for deletion and a sweeper
> removes them `retention_delete_delay` later — 24h by default. A restart inside that window, which
> is every redeploy, loses markers kept on ephemeral storage, and the chunks they name are already
> unlinked from the index. They then sit on the volume forever with nothing pointing at them, leaking
> exactly the space retention exists to reclaim.

The collectors and both Alloy services are stateless. Neither buffers telemetry to disk, so a volume
buys nothing — Alloy writes only an instance seed under `/var/lib/alloy/data`, regenerated if lost.
In-flight data is lost on restart either way.

## Configuration

All configuration is environment variables, set per Railway service. Defaults are shown where one
exists.

### Backend wiring

> The same variable name deliberately holds **different values in different services**. A collector
> needs a backend's OTLP path; Grafana needs its base URL. Railway scopes variables per service,
> which this relies on.

| Variable | Set on | Value |
| --- | --- | --- |
| `RAILWAY_LOKI_ENDPOINT` | gateways | `http://<loki>:3100/otlp` |
| `RAILWAY_LOKI_ENDPOINT` | grafana | `http://<loki>:3100` |
| `RAILWAY_TEMPO_ENDPOINT` | gateways | `http://<tempo>:4318` |
| `RAILWAY_TEMPO_ENDPOINT` | grafana | `http://<tempo>:3200` |
| `RAILWAY_PROMETHEUS_ENDPOINT` | gateways | `http://<prometheus>:9090/api/v1/otlp` |
| `RAILWAY_PROMETHEUS_ENDPOINT` | grafana | `http://<prometheus>:9090` |
| `RAILWAY_PROMETHEUS_REMOTE_WRITE_ENDPOINT` | tempo | `http://<prometheus>:9090/api/v1/write` |
| `RAILWAY_PROMETHEUS_ALERTMANAGER_ENDPOINT` | loki | Alertmanager URL, for the ruler. |

### Ingest authentication

Every service that accepts writes requires an explicit decision. Set exactly one of each pair.

| Variable | Applies to | Description |
| --- | --- | --- |
| `RAILWAY_OTEL_HTPASSWD` | `otelcol/gateway` | Require basic auth. One `user:password` line per producer, so any single producer can be rotated or revoked alone. Plaintext works; so does a bcrypt hash from `htpasswd -nbB <user> <password>`. |
| `RAILWAY_OTEL_ALLOW_UNAUTHENTICATED` | `otelcol/gateway` | `true` to run an open endpoint instead. |
| `FARO_API_KEY` | `alloy/*` | Require clients to send it as the `x-api-key` header. |
| `FARO_ALLOW_UNAUTHENTICATED` | `alloy/*` | `true` to run an open endpoint instead. |

> Validation: if neither variable in a pair is set, the service refuses to start and prints both
> options. Defaulting to open is how a public write endpoint gets exposed by forgetting a variable,
> so open stays supported but has to be asked for by name.

> ⚠️ **Warning**: an unauthenticated gateway is a write path into your whole stack.
>
> Anyone who finds the URL can write telemetry into your logs, traces and metrics — filling the
> volumes you pay for and polluting the data you make decisions from. Only opt out when the service
> has no public domain and is reachable on the private network alone.

The Faro key ships inside app bundles, so it filters noise rather than authenticating; the rate
limit, the payload cap and the CORS allowlist are the real controls on that path. An endpoint with no
key at all is still open to everyone who finds the URL.

### Faro ingest

| Variable | Default | Description |
| --- | --- | --- |
| `FARO_CORS_ALLOWED_ORIGINS` | local dev + native webview origins | Comma-separated frontend origins. **Replaces** the default rather than adding to it, so a deployment that sets it does not keep `localhost` allowed in production. |

The default covers `http://localhost`, `:3000`, `:5173` and the `capacitor://` / `ionic://` origins
iOS and Android webviews send, so both Alloy services are deployable with no edits. Changing it is a
variable edit and a restart — no image rebuild.

### Edge agent

| Variable | Default | Description |
| --- | --- | --- |
| `RAILWAY_OTEL_EXPORTER_OTLP_ENDPOINT` | — | Required. The gateway to forward to. |
| `RAILWAY_OTEL_UPSTREAM_AUTHORIZATION` | empty | `Basic <base64 user:password>` matching the gateway's htpasswd. Empty yields a 401 you can see in the logs rather than a startup crash. |
| `RAILWAY_DEPLOYMENT_ENVIRONMENT` | `prod` | Stamped as `deployment.environment.name` on everything passing through. |

### Alloy upstream

| Variable | Description |
| --- | --- |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | The gateway to forward to (`alloy/faro` only). |
| `OTEL_UPSTREAM_USERNAME` / `OTEL_UPSTREAM_PASSWORD` | Credentials for that gateway. Give Alloy its own line in the gateway's htpasswd so it can be rotated alone. |

## Examples

### Sending OTLP from an app on Railway

Deploy `otelcol/agent` in the app's project, pointed at the gateway:

```bash
RAILWAY_OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.example.com
RAILWAY_OTEL_UPSTREAM_AUTHORIZATION=Basic YXBwOnMzY3JldA==
RAILWAY_DEPLOYMENT_ENVIRONMENT=staging
```

Then point the app's SDK at the agent over the private network — no credentials needed on that hop:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://${{agent.RAILWAY_PRIVATE_DOMAIN}}:4318
```

### Browser RUM into an existing stack

Deploy `alloy/faro` with a public domain on port `12347`:

```bash
FARO_API_KEY=<key that ships in your app bundle>
FARO_CORS_ALLOWED_ORIGINS=https://app.example.com,https://staging.app.example.com
OTEL_EXPORTER_OTLP_ENDPOINT=http://${{gateway.RAILWAY_PRIVATE_DOMAIN}}:4318
OTEL_UPSTREAM_USERNAME=faro
OTEL_UPSTREAM_PASSWORD=<its own htpasswd line>
```

The Faro Web SDK posts to `https://<domain>/collect` with `x-api-key`. Lines land in Loki under
`service_namespace="faro"`, which is what the provisioned frontend dashboard queries.

### A private gateway with no auth

When the gateway has no public domain and only sibling services reach it:

```bash
RAILWAY_OTEL_ALLOW_UNAUTHENTICATED=true
```

It starts, logs three warnings saying the endpoint is open, and accepts unauthenticated writes.

## Local development

Configs are **copied into the image at build time**, not mounted, so a config change needs a
rebuild and redeploy. Upgrades are a one-line `ARG VERSION` bump in the service's `Dockerfile`.

```bash
# Build any service
docker build ./loki
docker build ./otelcol/gateway

# Verify Loki and Tempo — both reject unknown config keys, so a clean run here
# is a real schema check, not just YAML parsing
docker run --rm $(docker build -q ./loki) -config.file=/etc/loki/config.yaml -verify-config

# Verify Prometheus
docker run --rm --entrypoint promtool $(docker build -q ./prometheus) \
  check config /etc/prometheus/config.yaml

# Verify a collector config (auth.yaml is merged on top of config.yaml at runtime)
docker run --rm --entrypoint /otelcol-contrib \
  -e RAILWAY_OTEL_HTPASSWD=u:p -e RAILWAY_PROMETHEUS_ENDPOINT=x \
  -e RAILWAY_TEMPO_ENDPOINT=x -e RAILWAY_LOKI_ENDPOINT=x \
  $(docker build -q ./otelcol/gateway) \
  validate --config=file:/etc/otelcol/config.yaml --config=file:/etc/otelcol/auth.yaml

# Verify an Alloy config
docker run --rm --entrypoint /bin/alloy $(docker build -q ./alloy/gateway) \
  validate /etc/alloy/config.alloy
```
