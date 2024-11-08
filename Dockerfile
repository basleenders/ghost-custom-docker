FROM ghost:5-alpine

# Add GCS Adapter, from https://github.com/danmasta/ghost-gcs-adapter
RUN mkdir -p /tmp/gcs "$GHOST_INSTALL/current/core/server/adapters/storage/gcs"; \
    wget -O - -q "https://api.github.com/repos/danmasta/ghost-gcs-adapter/tarball/master" | tar xz --strip-components=1 -C /tmp/gcs ; \
    npm install --prefix /tmp/gcs --omit=dev --omit=optional --no-progress ; \
    mv -v /tmp/gcs/* "$GHOST_INSTALL/current/core/server/adapters/storage/gcs"

# Use the Ghost CLI to set (only) the neccessary config values.
RUN set -ex; \
    su-exec node ghost config storage.active gcs; \
    su-exec node ghost config storage.gcs.hashAlgorithm "sha512"; 

# Add my fork of the Casper i18n Theme from https://github.com/GenZmeY/casper-i18n/
RUN mkdir -p /tmp/custom ; \
    wget -O - -q "https://github.com/basleenders/casper-i18n/archive/refs/heads/master.tar.gz" | tar xz -C /tmp/custom ; \    
    mv -v /tmp/custom/* "$GHOST_INSTALL/content.orig/themes/casper-i18n" ; 
