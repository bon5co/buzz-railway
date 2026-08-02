# Buzz relay, packaged for Railway.
#
# Pinned by digest rather than :main. Buzz ships roughly daily and its Postgres
# migrations are one-way, so a moving tag means two deploys a week apart are not
# the same product -- and a rollback is not available once the schema has moved.
FROM ghcr.io/block/buzz@sha256:b4148c43a9acb0b68a8528927610683997fc11a7f48cd890c85b5f5588e3329a

# Every value here is a literal that Railway's template generator would drop
# (it keeps a defaultValue only when the live value is a Railway expression), so
# baking them in is what keeps the deploy form down to the one field that is
# genuinely the deployer's.
ENV PORT=3000 \
    BUZZ_AUTO_MIGRATE=true \
    BUZZ_REQUIRE_AUTH_TOKEN=true \
    BUZZ_REQUIRE_RELAY_MEMBERSHIP=true \
    BUZZ_ALLOW_NIP_OA_AUTH=true \
    BUZZ_GIT_CONFORMANCE_PROBE=true \
    BUZZ_GIT_REPO_PATH=/data/git \
    BUZZ_SERVE_GIT_WEB_GUI=true \
    BUZZ_S3_BUCKET=buzz-media \
    BUZZ_S3_ACCESS_KEY=buzz

COPY npub2hex.pl /usr/local/bin/npub2hex.pl
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh

USER root
RUN chmod 0755 /usr/local/bin/npub2hex.pl /usr/local/bin/railway-entrypoint.sh
# Back to upstream's unprivileged user. The relay needs no root at runtime and
# this template mounts no volume on it, so there is nothing to chown.
USER buzz

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["/usr/local/bin/buzz-relay"]
