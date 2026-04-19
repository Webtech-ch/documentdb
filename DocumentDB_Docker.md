# DocumentDB 

DocumentDB docker imgage.


## Running

To run the container, use `docker run` or `docker-compose`

```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
         - "5432:5432"
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
```

The DocumentDB gateway endpoint is available on port `27017` by default. To access this with `mongosh`, run:

```sh
mongosh "mongodb://user:password@localhost:27017/?directConnection=true"
```

> **TLS note:** TLS is opt-in and disabled by default. To connect with TLS, see the [TLS](#tls) section below.

## DocumentDB User Management
`DOCUMENTDB_USER` and `DOCUMENTDB_PASSWORD` is the mongodb Admin user. Additional user with limited privileges can be configured through mongodb admin tools.
```sh
use admin
db.createUser({
  user: "myuser",
  pwd: "mypassword",
  roles: [
    { role: "readWrite", db: "test" },
  ]
})
```

## Docker commands and .env vars

The following table summarizes the available CLI flags and environment variables for configuring the container.

| Description | CLI flag | Environment variable | Allowed values | Default | Notes |
|---|---|---|---|---|---|
| Display help | `--help`, `-h` | — | — | — | Prints all available configuration options to stdout. |
| DocumentDB username | `--documentdb-user [value]` | `DOCUMENTDB_USER` | STRING | — | **Required.** MongoDB-protocol admin user (`clusterAdmin + readWriteAnyDatabase` roles). |
| DocumentDB password | `--documentdb-password [value]` | `DOCUMENTDB_PASSWORD` | STRING | — | **Required.** Password for the DocumentDB user. |
| DocumentDB endpoint port | `--documentdb-port [value]` | `DOCUMENTDB_PORT` | INT | `27017` | Must also be published via `-p 27017:27017`. |
| PostgreSQL port | `--pg-port [value]` | `POSTGRESQL_PORT` | INT | `5432` | Internal PostgreSQL server port. |
| PostgreSQL database | — | `DOCUMENTDB_DATABASE` | STRING | `documentdb` | The PostgreSQL database used by the gateway. |
| Data directory | `--data-path [value]` | `DATA_PATH` | STRING | `/data` | Mount a host path here to persist data: `--mount type=bind,source=./.local/data,target=/data`. |
| Owner | `--owner [value]` | `OWNER` | STRING | `documentdb` | PostgreSQL peer-auth superuser. No password; Unix socket only. |
| Allow external PostgreSQL connections | `--postgres-allow-external-connections [value]` | `POSTGRES_ALLOW_EXTERNAL_CONNECTIONS` | `true`, `false` | `true` | When `true`, PostgreSQL listens on all interfaces with SCRAM-SHA-256 auth. |
| Create PostgreSQL superuser | `--postgres-user [value]` | `POSTGRES_USER` | STRING | — | Creates a PostgreSQL superuser for direct `psql` access. Both `--postgres-user` and `--postgres-password` must be set together. |
| PostgreSQL superuser password | `--postgres-password [value]` | `POSTGRES_PASSWORD` | STRING | — | Password for the PostgreSQL superuser. Both `--postgres-user` and `--postgres-password` must be set together. |
| Start PostgreSQL server | `--start-pg [value]` | — | `true`, `false` | `true` | Set to `false` to skip starting the internal PostgreSQL instance. |
| Create DocumentDB user | `--create-user [value]` | — | `true`, `false` | `true` | Set to `false` to skip user creation at startup. |
| Skip built-in sample data | `--skip-init-data` | `SKIP_INIT_DATA` | `true`, `false` | `true` | Start without loading the default sample collections. Set to `false` to enable built-in sample data. |
| Custom init scripts directory | `--init-data-path [PATH]` | `INIT_DATA_PATH` | STRING | `/init_doc_db.d` | Every `.js` file in the mounted directory is executed with `mongosh` in alphabetical order. Automatically disables built-in sample data. |
| Disable extended RUM indexes | `--disable-extended-rum` | `DISABLE_EXTENDED_RUM` | — | `false` | Disables use of `extended_rum` for indexes. |
| Enable TLS | `--tls-enabled` | `TLS_ENABLED` | `true`, `false` | `false` | Enables TLS using auto-generated certificates. Automatically set to `true` when `--cert-path` and `--key-file` are both provided. |
| TLS certificate path | `--cert-path [PATH]` | `CERT_PATH` | STRING | — | Path to a PEM certificate file. Mount into the container: `--mount type=bind,source=./cert.pem,target=/cert.pem`. Set `CERT_SECRET` for a password-protected certificate. |
| TLS key file path | `--key-file [PATH]` | `KEY_FILE` | STRING | — | Path to the private key file. Mount into the container: `--mount type=bind,source=./key.pem,target=/key.pem`. Must be set together with `--cert-path`. |
| Enable telemetry | `--enable-telemetry [value]` | `ENABLE_TELEMETRY` | `true`, `false` | `false` | Sends usage data to Azure Application Insights. |
| Log level | `--log-level [value]` | `LOG_LEVEL` | `quiet`, `error`, `warn`, `info`, `debug`, `trace` | `info` | Verbosity of logs emitted by the gateway. |



## TLS

TLS is **opt-in** and disabled by default.

### Enable TLS with auto-generated certificates

```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
         TLS_ENABLED: "true"
```

Copy the generated certificate from the container to connect with `mongosh`:

```sh
docker cp docdb:/home/documentdb/gateway/pg_documentdb_gw/cert.pem ~/documentdb-cert.pem

mongosh localhost:27017 -u user -p password \
  --authenticationMechanism SCRAM-SHA-256 \
  --tls --tlsCAFile ~/documentdb-cert.pem
```

### Enable TLS with custom certificates

```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
      volumes:
         - ./cert.pem:/cert.pem
         - ./key.pem:/key.pem
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
         CERT_PATH: /cert.pem
         KEY_FILE: /key.pem
```

## PostgreSQL superuser access

When both `--postgres-user` and `--postgres-password` are set, a PostgreSQL superuser is created for direct `psql` access to the underlying PostgreSQL instance.

```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
         - "5432:5432"
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
         POSTGRES_USER: pgAdmin
         POSTGRES_PASSWORD: password
```

> **Note:** This is separate from `--documentdb-user`, which is the MongoDB-protocol application user. The PostgreSQL superuser (`OWNER`, default: `documentdb`) uses peer authentication via Unix socket.

## Persist data
```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
      volumes:
         - ./data:/data
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
```

## Override the PostgreSQL database name
```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
         - "5432:5432"
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
         DOCUMENTDB_DATABASE: mydb
```


## Data initialization

DocumentDB Local skips built-in sample data by default. 

If you `SKIP_INIT_DATA:false`, a `sampledb` database is created with `users`, `products`, `orders`, and `analytics` collections (5 users, 5 products, 4 orders, 2 analytics records).

### Skip sample data

```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
         - "5432:5432"
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
         LOG_LEVEL: warn
         SKIP_INIT_DATA: false
```

### Use custom initialization scripts

```yaml
services:
   documentdb:
      image: documentdb:latest
      ports:
         - "27017:27017"
      volumes:
         - ./init-scripts:/init_doc_db.d
      environment:
         DOCUMENTDB_USER: user
         DOCUMENTDB_PASSWORD: password
         INIT_DATA_PATH: /init_doc_db.d
```

When `INIT_DATA_PATH` is provided, built-in sample data is automatically disabled and only your scripts are run. Scripts are executed in alphabetical order using `mongosh`.
