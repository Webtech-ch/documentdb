```
# Build with defaults (PG 17, tagged as documentdb — matches official latest)
./packaging/webtech_build.sh

# Build for a different PG version
./packaging/webtech_build.sh --pg 16

# Custom image tag
./packaging/webtech_build.sh --pg 17 --tag documentdb:1.0
```

## Recent changes

### Default PostgreSQL port reverted to 5432
The internal PostgreSQL port default has been changed back from `9712` to the standard PostgreSQL port `5432`. This affects:
- `SetupConfiguration.json` (`PostgresPort`)
- `Dockerfile_gateway` and `Dockerfile_deb_gateway_test` (`POSTGRESQL_PORT` env var)
- `scripts/build_and_start_gateway.sh` (`-P` flag default)
- `scripts/emulator_entrypoint.sh` (`POSTGRESQL_PORT` default)
- `scripts/start_oss_server.sh` (`coordinatorPort` default)

The gateway listen port (`GatewayListenPort: 10260`) is unchanged.

### TLS is now opt-in (`TlsEnabled`)
A new `TlsEnabled` configuration parameter controls whether TLS is active. It defaults to `false`, making TLS optional instead of mandatory.

- **`SetupConfiguration.json`**: `"TlsEnabled": false` is now present by default.
- **`enforce_tls`** default also changed from `true` to `false`. Setting `enforce_tls: true` while `tls_enabled: false` is a validation error.
- **`emulator_entrypoint.sh`**: TLS is automatically enabled (`.TlsEnabled = true`) only when both `CERT_PATH` and `KEY_FILE` are provided.
- **`init_documentdb_data.sh`**: Added a `--tls` flag. `mongosh` connections no longer pass `--tls --tlsAllowInvalidCertificates` unconditionally; TLS options are only added when `--tls` is passed. The entrypoint script passes `--tls` to `init_documentdb_data.sh` only when TLS is enabled.
- Internally, `TlsProvider` is now `Option<TlsProvider>` throughout the gateway core, so no TLS certificates are required when TLS is disabled.

