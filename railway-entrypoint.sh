#!/bin/sh
# Railway entrypoint for buzz-relay.
#
# Does two things upstream's image cannot do for itself on Railway:
#
#  1. Accepts the key the Buzz app actually gives you. The app's "Copy your
#     public ID" button yields a NIP-19 `npub1...`, but buzz-relay's config
#     loader accepts *only* 64 lowercase hex characters and warn-and-ignores
#     anything else -- which, with membership enforcement on, aborts the boot
#     with "RELAY_OWNER_PUBKEY required". Decoding it here means the value the
#     deployer has in their clipboard is the value that works.
#
#  2. Refuses an `nsec1...` outright. Pasting a private key where a public key
#     belongs would hand relay ownership to anyone who reads the deploy config.
#
# This runs as the image's own unprivileged `buzz` user; nothing here needs root.
set -eu

case "${RELAY_OWNER_PUBKEY:-}" in
  nsec1*)
    echo "buzz: RELAY_OWNER_PUBKEY is an nsec (a PRIVATE key). Refusing to start." >&2
    echo "buzz: paste your PUBLIC id instead -- in the Buzz app it is the" >&2
    echo "buzz: 'Copy your public ID' button on the join-a-community screen." >&2
    exit 1
    ;;
  npub1*)
    if ! hex="$(perl /usr/local/bin/npub2hex.pl "$RELAY_OWNER_PUBKEY")"; then
      echo "buzz: could not decode RELAY_OWNER_PUBKEY as an npub (see above)." >&2
      exit 1
    fi
    echo "buzz: decoded RELAY_OWNER_PUBKEY npub -> ${hex}"
    RELAY_OWNER_PUBKEY="$hex"
    export RELAY_OWNER_PUBKEY
    ;;
  "")
    echo "buzz: RELAY_OWNER_PUBKEY is empty -- the relay would start with no owner." >&2
    echo "buzz: set it to your Buzz public id (npub1... or 64-char hex)." >&2
    exit 1
    ;;
esac

# The git scratch directory is not authoritative state (upstream:
# docs/git-on-object-storage.md) but it does have to be writable, and it is the
# one path that breaks if someone mounts a Railway volume here -- Railway mounts
# volumes owned by uid 0 while this image runs as uid 1000. Fail with the reason
# rather than deep inside a git subprocess.
GIT_DIR="${BUZZ_GIT_REPO_PATH:-/data/git}"
mkdir -p "$GIT_DIR" 2>/dev/null || true
if ! [ -w "$GIT_DIR" ]; then
  echo "buzz: git scratch dir $GIT_DIR is not writable by uid $(id -u)." >&2
  echo "buzz: this template deliberately mounts no volume here -- if you added" >&2
  echo "buzz: one, remove it (the authoritative git state lives in object" >&2
  echo "buzz: storage) or set RAILWAY_RUN_UID=0." >&2
  exit 1
fi

# Wait for the object store. Railway starts every service at once, and the relay
# runs its git object-store conformance probe (the A3 gate) during boot: if the
# store is not answering yet the probe fails and the process EXITS. It would be
# restarted and would eventually come up, but the first deploy is the one the
# deployer is watching, and "git conformance probe failed" reads like a broken
# template rather than a service that started 20 seconds early.
if [ -n "${BUZZ_S3_ENDPOINT:-}" ]; then
  attempt=0
  until curl -s -o /dev/null --max-time 3 "$BUZZ_S3_ENDPOINT" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 60 ]; then
      echo "buzz: object store at $BUZZ_S3_ENDPOINT still unreachable after 120s" >&2
      echo "buzz: starting anyway so the conformance probe reports the real error." >&2
      break
    fi
    [ "$attempt" = 1 ] && echo "buzz: waiting for object store at $BUZZ_S3_ENDPOINT ..."
    sleep 2
  done
fi

exec "$@"
