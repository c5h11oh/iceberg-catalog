# Local Iceberg REST catalog playground

This Compose stack runs an [Apache Iceberg REST catalog](http://localhost:8181)
backed by a local [RustFS](http://localhost:9001) S3-compatible store. Catalog
metadata and table data are written to `s3://warehouse/iceberg` by default.

The equivalent standalone Podman commands are in
[commands.sh](/home/sven/iceberg-catalog/commands.sh).

Start it with:

```sh
cp .env-example .env  # first run only; customize local values if needed
podman compose up -d
```

All images use fully qualified `docker.io/...` references, so this also works
with Podman installations that do not configure short-name registries.

Useful endpoints:

- REST catalog: `http://localhost:8181`
- RustFS S3 API: `http://localhost:9000`
- RustFS console: `http://localhost:9001` (default login: `ICEBERGADMIN` / `iceberg-local-secret`)

The default catalog configuration for an S3-capable client is:

```text
uri = http://localhost:8181
warehouse = s3://warehouse/iceberg
s3.endpoint = http://localhost:9000
s3.access-key-id = ICEBERGADMIN
s3.secret-access-key = iceberg-local-secret
s3.path-style-access = true
```

## Spark SQL

The stack also includes Spark with an Iceberg REST catalog named `demo`. Open a
SQL shell after the services are up:

```sh
podman-compose exec spark-iceberg spark-sql
```

The containers share the `iceberg-catalog` Podman network. Use that network name
when running a standalone client container.

Within that network, use `http://iceberg-rest:8181` for the catalog and
`http://iceberg-rustfs:9000` for S3. From the host, use `localhost` instead.

For example:

```sql
CREATE NAMESPACE IF NOT EXISTS demo.playground;
SHOW NAMESPACES;
CREATE TABLE demo.playground.people (id BIGINT, name STRING) USING iceberg;
INSERT INTO demo.playground.people VALUES (1, 'Ada'), (2, 'Grace');
SELECT * FROM demo.playground.people;
```

Spark's optional notebook UI is available at `http://localhost:8888` and its
master UI at `http://localhost:8080`.

Set `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY`, or `WAREHOUSE_BUCKET` in `.env`
to override the defaults. Compose loads this file automatically. The
`iceberg-catalog-rustfs` named volume keeps the warehouse between restarts. To
remove all local data:

```sh
podman compose down -v
```

PyIceberg reads `.pyiceberg.yaml` from this directory. Its values can be
overridden with the `PYICEBERG_...` variables in `.env`; export them before
running the CLI directly:

```sh
set -a; . ./.env; set +a
pyiceberg --catalog local list
```
