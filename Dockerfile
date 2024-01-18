FROM ghost:5-alpine

# Add GCS Adapter, from https://github.com/danmasta/ghost-gcs-adapter
RUN mkdir -p /tmp/gcs "$GHOST_INSTALL/current/core/server/adapters/storage/gcs"; \
    wget -O - -q "$(npm view @danmasta/ghost-gcs-adapter dist.tarball)" | tar xz -C /tmp/gcs ; \
    npm install --prefix /tmp/gcs/package --omit=dev --omit=optional --no-progress ; \
    mv -v /tmp/gcs/package/* "$GHOST_INSTALL/current/core/server/adapters/storage/gcs"

# Use the Ghost CLI to set some pre-defined values.
RUN set -ex; \
    su-exec node ghost config storage.active gcs; \
    su-exec node ghost config storage.gcs.host "storage.googleapis.com"; \
    su-exec node ghost config storage.gcs.protocol "https"; \
    su-exec node ghost config storage.gcs.hash true; \
    su-exec node ghost config storage.gcs.hashAlgorithm "sha512"; \
    su-exec node ghost config storage.gcs.hashLength "16"; 

# Add my fork of the Casper i18n Theme from https://github.com/GenZmeY/casper-i18n/
RUN mkdir -p /tmp/custom ; \
    wget -O - -q "https://github.com/basleenders/casper-i18n/archive/refs/heads/master.tar.gz" | tar xz -C /tmp/custom ; \    
    mv -v /tmp/custom/* "$GHOST_INSTALL/content.orig/themes/casper-i18n" ; \
    mv ./redirects.json $GHOST_INSTALL/settings/
