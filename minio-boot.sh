#!/bin/sh
# Start MinIO and make sure Buzz's bucket exists, in one service.
#
# Two reasons this is an entrypoint rather than a Railway start command:
# upstream's image prints a help screen and exits unless it is given a `server`
# subcommand, and the bucket normally needs a second `minio/mc` container.
# Baking both in means the template needs no start command at all -- and a start
# command would replace this ENTRYPOINT, silently skipping the bucket creation.
set -eu

: "${MINIO_ROOT_USER:?MINIO_ROOT_USER is required}"
: "${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required}"

BUCKET="${BUZZ_S3_BUCKET:-buzz-media}"
DATA="${MINIO_DATA_DIR:-/data/minio}"
LISTEN_PORT="${PORT:-9000}"

# mc writes its config under $HOME, which on Railway is a mounted volume whose
# root dir is owned by uid 0; keep it on the container filesystem instead.
export MC_CONFIG_DIR=/tmp/.mc

# Railway mounts volumes root-owned and with a lost+found directory inside them,
# so MinIO's data lives one level below the mount rather than at its root --
# the same reason Postgres keeps PGDATA in a subdirectory of its volume.
mkdir -p "$DATA"

minio server "$DATA" --address ":$LISTEN_PORT" &
MINIO_PID=$!

attempt=0
until mc alias set local "http://127.0.0.1:$LISTEN_PORT" \
  "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -gt 60 ]; then
    echo "minio-boot: server did not become reachable within 60s" >&2
    kill "$MINIO_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

# --ignore-existing: this runs on every boot, and after the first one the bucket
# (and everything in it) is already there on the volume.
mc mb --ignore-existing "local/$BUCKET" >/dev/null
mc anonymous set none "local/$BUCKET" >/dev/null
echo "minio-boot: bucket $BUCKET ready on :$LISTEN_PORT (data dir $DATA)"

wait "$MINIO_PID"
