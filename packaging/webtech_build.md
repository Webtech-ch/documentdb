```
# Build with defaults (PG 17, tagged as documentdb — matches official latest)
./packaging/webtech_build.sh

# Build for a different PG version
./packaging/webtech_build.sh --pg 16

# Custom image tag
./packaging/webtech_build.sh --pg 17 --tag documentdb:1.0
```

## Recent changes

### Log handling overhaul (`LOG_LEVEL`)

Several fixes and behaviour changes were made to how `LOG_LEVEL` is handled across the stack.

#### `LOG_LEVEL` now actually works

Previously `LOG_LEVEL` was validated and exported in `scripts/emulator_entrypoint.sh` but never passed to anything — both the gateway and PostgreSQL ignored it entirely.

- **Gateway (Rust):** `LOG_LEVEL` is now translated to `RUST_LOG` before the gateway process starts, which is the env var the Rust `tracing` crate respects. `quiet` maps to `RUST_LOG=off` since Rust's tracing crate has no quiet level.
- **PostgreSQL:** `LOG_LEVEL` is translated to `log_min_messages` via `ALTER SYSTEM` + `pg_reload_conf()` immediately after the OSS server starts.

#### PostgreSQL `LOG_LEVEL` → `log_min_messages` mapping

| `LOG_LEVEL` | `log_min_messages` | Notes |
|---|---|---|
| `quiet` | `panic` | Suppresses everything except server crashes |
| `error` | `log` | Shows PostgreSQL `LOG`-level and above |
| `warn` | `warning` | Suppresses `LOG`-level cron/vacuum noise |
| `info` | `notice` | Default — startup notices and above |
| `debug` | `debug2` | Verbose internal state |
| `trace` | `debug5` | Maximum verbosity |

> **Note:** In PostgreSQL's `log_min_messages` hierarchy, `LOG` ranks *above* `ERROR` (`WARNING < ERROR < LOG < FATAL`). This means `warning` correctly suppresses the noisy cron/vacuum `LOG:` messages that were previously visible even at `warn` level.

#### pg_cron logging suppressed at `warn` and below

`pg_cron` emits a `LOG:` entry for every job execution (`cron job N starting`, `cron job N COMMAND completed`). At `LOG_LEVEL=warn`, `error`, or `quiet`, the entrypoint now also sets:
```sql
ALTER SYSTEM SET cron.log_run = 'off';
ALTER SYSTEM SET cron.log_statement = 'off';
```
This disables pg_cron's per-job logging at source rather than relying on filtering.

#### Stream-level filtering

The `start_log_streaming` function in `emulator_entrypoint.sh` now accepts an optional `grep -v` filter pattern. At `warn`/`error`/`quiet`, any remaining ` LOG: ` lines that pass through `log_min_messages` (e.g. from background workers) are filtered from the streamed output before they reach `docker logs`.

#### `DOCUMENTDB_USER` and `DOCUMENTDB_PASSWORD` are now required

The defaults (`default_user` / `Admin100`) have been removed. Both must now be provided explicitly, either via CLI flags or environment variables. The container exits with an error if either is missing.

#### `SKIP_INIT_DATA` defaults to `true`

Built-in sample data is no longer loaded by default. To re-enable it:
```sh
docker run -dt -e SKIP_INIT_DATA=false -p 27017:27017 documentdb \
  --documentdb-user user --documentdb-password pass
```

This affects:
- `scripts/emulator_entrypoint.sh` (`SKIP_INIT_DATA` default, `LOG_LEVEL` → `RUST_LOG` translation, `log_min_messages` + `cron.log_run`/`cron.log_statement` via `psql`, stream filter pattern)

### Database name changed from `postgres` to `documentdb`
DocumentDB now uses a dedicated `documentdb` database instead of the default `postgres` database. The database is automatically created during server initialization. This affects:
- `pg_documentdb_gw/documentdb_gateway_core/src/configuration/setup.rs` (Rust default: `unwrap_or("documentdb")`)
- `pg_documentdb_gw/SetupConfiguration.json` (`PostgresDatabase` field added)
- `pg_documentdb/src/configs/background_job_configs.c` (`DEFAULT_BG_DATABASE_NAME`)
- `.github/containers/Build-Ubuntu/Dockerfile_gateway` (`DOCUMENTDB_DATABASE` env var)
- `scripts/utils.sh` (`DOCUMENTDB_DATABASE` env var, `cron.database_name`, `bg_worker_database_name`)
- `scripts/start_oss_server.sh` (`CREATE DATABASE` bootstrap, gateway config, all `psql` calls)
- Test Makefiles (`--dbname=documentdb` for `installcheck` and multinode targets)

The database name is controlled by the `DOCUMENTDB_DATABASE` environment variable (default: `documentdb`). To override:
```sh
# To set a new default to the container:
export DOCUMENTDB_DATABASE=documentdb
./scripts/start_oss_server.sh ...

# When starting the Docker container, you can override the default with DOCUMENTDB_DATABASE
docker run -dt -e DOCUMENTDB_DATABASE=mydb -p 27017:27017 documentdb --documentdb-user user --documentdb-password pass
```

### PostgreSQL default port reverted to 5432
The internal PostgreSQL port default has been changed back from `9712` to the standard PostgreSQL port `5432`. This affects:
- `SetupConfiguration.json` (`PostgresPort`)
- `Dockerfile_gateway` and `Dockerfile_deb_gateway_test` (`POSTGRESQL_PORT` env var)
- `scripts/build_and_start_gateway.sh` (`-P` flag default)
- `scripts/emulator_entrypoint.sh` (`POSTGRESQL_PORT` default)
- `scripts/start_oss_server.sh` (`coordinatorPort` default)

The gateway listen port (`GatewayListenPort`) has been changed from `10260` to the standard MongoDB port `27017`.

The port is controlled by the `POSTGRESQL_PORT` environment variable (default: `5432`). To override:
```sh
# When running scripts directly
export POSTGRESQL_PORT=5433
./scripts/start_oss_server.sh ...

# When starting the Docker container, you can override the default with POSTGRESQL_PORT
docker run -dt -e POSTGRESQL_PORT=5433 -p 27017:27017 documentdb --documentdb-user user --documentdb-password pass

# Or via the CLI flag
docker run -dt -p 27017:27017 documentdb --pg-port 5433 --documentdb-user user --documentdb-password pass
```

### External PostgreSQL connections (`POSTGRES_ALLOW_EXTERNAL_CONNECTIONS`)
Controls whether the internal PostgreSQL instance accepts connections from outside the container. When `true`, PostgreSQL listens on all interfaces (`listen_addresses = '*'`) and allows SCRAM-SHA-256 authenticated connections from any IP. This affects:
- `Dockerfile_gateway` and `Dockerfile_deb_gateway_test` (`POSTGRES_ALLOW_EXTERNAL_CONNECTIONS` env var)
- `scripts/emulator_entrypoint.sh` (CLI flag `--postgres-allow-external-connections`, default handling)

Renamed from `ALLOW_EXTERNAL_CONNECTIONS` to `POSTGRES_ALLOW_EXTERNAL_CONNECTIONS`. CLI flag renamed from `--allow-external-connections` to `--postgres-allow-external-connections`. Default changed to `true`. Also fixed a bug where the previous implementation was an assignment (`if ALLOW_EXTERNAL_CONNECTIONS="true"`) instead of a comparison, causing it to always evaluate as true.

To override:
```sh
# Disable external PostgreSQL connections
docker run -dt -e POSTGRES_ALLOW_EXTERNAL_CONNECTIONS=false -p 27017:27017 documentdb --documentdb-user user --documentdb-password pass

# Or via the CLI flag
docker run -dt -p 27017:27017 documentdb --postgres-allow-external-connections false --documentdb-user user --documentdb-password pass
```

### PostgreSQL superuser (`POSTGRES_USER` / `POSTGRES_PASSWORD`)
When both `POSTGRES_USER` and `POSTGRES_PASSWORD` are set, a PostgreSQL superuser is created after the server starts. This gives direct `psql` access to the underlying PostgreSQL instance (useful for advanced administration, schema inspection, or direct SQL access).

Note: This is distinct from `DOCUMENTDB_USER` / `DOCUMENTDB_PASSWORD`, which is the MongoDB-protocol application user accessed via port 27017.

```sh
# Via env vars
docker run -dt \
  -e POSTGRES_USER=pgadmin \
  -e POSTGRES_PASSWORD=secret \
  -p 27017:27017 -p 5432:5432 \
  documentdb --documentdb-user user --documentdb-password pass

# Via CLI flags
docker run -dt -p 27017:27017 -p 5432:5432 documentdb \
  --postgres-user pgadmin --postgres-password secret \
  --documentdb-user user --documentdb-password pass
```

### DocumentDB user renamed (`DOCUMENTDB_USER` / `DOCUMENTDB_PASSWORD`)
The `USERNAME` and `PASSWORD` environment variables and `--username`/`--password` CLI flags have been renamed to better reflect their purpose. This affects:
- `scripts/emulator_entrypoint.sh` (CLI flags and env var defaults)
- `.github/containers/Build-Ubuntu/Dockerfile_gateway` (`DOCUMENTDB_USER` env var)
- `packaging/test_packages/deb/Dockerfile_deb_gateway_test` (`DOCUMENTDB_USER` env var)
- `packaging/test_packages/test-gateway-install-entrypoint.sh` (CLI flag calls)

Renamed:
- `USERNAME` → `DOCUMENTDB_USER` (default: `default_user`)
- `PASSWORD` → `DOCUMENTDB_PASSWORD` (default: `Admin100`)
- `--username` → `--documentdb-user`
- `--password` → `--documentdb-password`

Note: `DOCUMENTDB_USER` is the MongoDB-protocol admin user (with `clusterAdmin + readWriteAnyDatabase` roles), not the PostgreSQL superuser. The PostgreSQL superuser is `OWNER` (default: `documentdb`), which uses peer authentication via Unix socket and has no password.

To override:
```sh
# Via env vars
docker run -dt -e DOCUMENTDB_USER=myuser -e DOCUMENTDB_PASSWORD=mypass -p 27017:27017 documentdb

# Via CLI flags
docker run -dt -p 27017:27017 documentdb --documentdb-user myuser --documentdb-password mypass
```

### TLS is now opt-in (`TlsEnabled`)
A new `TlsEnabled` configuration parameter controls whether TLS is active. It defaults to `false`, making TLS optional instead of mandatory.

- **`SetupConfiguration.json`**: `"TlsEnabled": false` is now present by default.
- **`enforce_tls`** default also changed from `true` to `false`. Setting `enforce_tls: true` while `tls_enabled: false` is a validation error.
- **`emulator_entrypoint.sh`**: TLS is automatically enabled (`.TlsEnabled = true`) only when both `CERT_PATH` and `KEY_FILE` are provided.
- **`init_documentdb_data.sh`**: Added a `--tls` flag. `mongosh` connections no longer pass `--tls --tlsAllowInvalidCertificates` unconditionally; TLS options are only added when `--tls` is passed. The entrypoint script passes `--tls` to `init_documentdb_data.sh` only when TLS is enabled.
- Internally, `TlsProvider` is now `Option<TlsProvider>` throughout the gateway core, so no TLS certificates are required when TLS is disabled.


```sh
# Via env var
docker run -e TLS_ENABLED=true ...

# Via CLI flag
docker run ... documentdb --tls-enabled --documentdb-user user --documentdb-password pass

# Via certs (unchanged, still auto-enables TLS)
docker run ... documentdb --cert-path /cert.pem --key-file /key.pem ...
```