#!/usr/bin/env bash
set -eu

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

RUSTFS_ACCESS_KEY="${RUSTFS_ACCESS_KEY:-ICEBERGADMIN}"
RUSTFS_SECRET_KEY="${RUSTFS_SECRET_KEY:-iceberg-local-secret}"
WAREHOUSE_BUCKET="${WAREHOUSE_BUCKET:-warehouse}"

podman run --replace -d --name iceberg-rustfs --network iceberg-catalog \
  -p 127.0.0.1:9000:9000 -p 127.0.0.1:9001:9001 \
  -v iceberg-catalog-rustfs:/data \
  -e RUSTFS_ACCESS_KEY="$RUSTFS_ACCESS_KEY" \
  -e RUSTFS_SECRET_KEY="$RUSTFS_SECRET_KEY" \
  docker.io/rustfs/rustfs:latest /data

podman run --replace -d --name iceberg-rest --network iceberg-catalog \
  -p 127.0.0.1:8181:8181 \
  -e AWS_ACCESS_KEY_ID="$RUSTFS_ACCESS_KEY" \
  -e AWS_SECRET_ACCESS_KEY="$RUSTFS_SECRET_KEY" \
  -e AWS_REGION=us-east-1 \
  -e CATALOG_WAREHOUSE="s3://${WAREHOUSE_BUCKET}/iceberg" \
  -e CATALOG_IO__IMPL=org.apache.iceberg.aws.s3.S3FileIO \
  -e CATALOG_S3_ENDPOINT=http://iceberg-rustfs:9000 \
  -e CATALOG_S3_PATH__STYLE__ACCESS=true \
  docker.io/apache/iceberg-rest-fixture:latest

pyiceberg --catalog local list

podman run --rm -it \
  --network iceberg-catalog \
  -e AWS_ACCESS_KEY_ID="$RUSTFS_ACCESS_KEY" \
  -e AWS_SECRET_ACCESS_KEY="$RUSTFS_SECRET_KEY" \
  -e AWS_REGION=us-east-1 \
  --entrypoint /opt/spark/bin/spark-sql \
  docker.io/tabulario/spark-iceberg:latest \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.demo=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.demo.type=rest \
  --conf spark.sql.catalog.demo.uri=http://iceberg-rest:8181 \
  --conf spark.sql.catalog.demo.warehouse="s3://${WAREHOUSE_BUCKET}/iceberg" \
  --conf spark.sql.catalog.demo.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
  --conf spark.sql.catalog.demo.s3.endpoint=http://iceberg-rustfs:9000 \
  --conf spark.sql.catalog.demo.s3.path-style-access=true \
  --conf spark.sql.defaultCatalog=demo
