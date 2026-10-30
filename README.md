# buzz-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/buzz-relay-or-block-ai-agent-workspace-r?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Buzz Relay template](https://railway.com/deploy/buzz-relay-or-block-ai-agent-workspace-r?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Railway packaging for [Buzz](https://github.com/block/buzz), Block's hive-mind
workspace where humans and AI agents share channels, threads, DMs, code review
and git history as signed events on a Nostr relay you own.

Two thin images. Neither forks Buzz; both wrap the official release.

## `ghcr.io/bon5co/buzz-railway`

`FROM ghcr.io/block/buzz@sha256:b4148c…` plus:

- **`npub` support.** The Buzz app's "Copy your public ID" button gives you a
  NIP-19 `npub1…`, but `buzz-relay` accepts *only* 64 lowercase hex characters —
  `config.rs` warn-and-ignores anything else, and with membership enforcement on
  the boot then aborts with `RELAY_OWNER_PUBKEY required`. `npub2hex.pl` decodes
  it, checksum included, so a mistyped key fails loudly instead of resolving to
  a valid-looking hex key that locks you out of your own relay. An `nsec1…`
  (private key) is refused outright.
- **Upstream's production defaults, baked in.** `BUZZ_REQUIRE_RELAY_MEMBERSHIP`
  and `BUZZ_REQUIRE_AUTH_TOKEN` both default to `false` in the binary; the Helm
  chart calls `true` "the production default". A relay with membership
  enforcement off is an open relay.
- **Still unprivileged.** Runs as the image's own uid 1000 `buzz` user.

## `ghcr.io/bon5co/buzz-railway-minio`

`FROM minio/minio:RELEASE.2025-09-07T16-13-09Z`, starts the server and creates
the `buzz-media` bucket in one service — upstream's image exits with a help
screen without a `server` subcommand, and the bucket otherwise needs a second
`minio/mc` container. Both are baked into the ENTRYPOINT, so the template needs
no start command (which would replace the ENTRYPOINT and skip bucket creation).

Its data dir sits one level below the volume mount, because Railway mounts
volumes root-owned and with a `lost+found` inside them.

**This service is where the workspace actually lives.** Buzz keeps no
authoritative repository state on local disk — every git request hydrates an
ephemeral working tree from object storage and drops it again
([`docs/git-on-object-storage.md`](https://github.com/block/buzz/blob/main/docs/git-on-object-storage.md)).
An object store without a volume loses every repo and every attachment on each
redeploy while the chat history in Postgres survives, so the workspace comes
back looking intact with every clone and every image broken.

## Licence

Buzz is Apache-2.0, © Block, Inc. These files only package it.
