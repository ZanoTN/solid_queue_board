FROM mcr.microsoft.com/devcontainers/ruby:4-3.4-trixie

# SQLite CLI and headers (the sqlite3 gem ships precompiled binaries, but the
# headers allow a native build if a platform gem is not available).
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
	&& apt-get -y install --no-install-recommends sqlite3 libsqlite3-dev \
	&& rm -rf /var/lib/apt/lists/*

# Let the vscode user install gems into the shared GEM_HOME.
RUN groupadd --system rubygems \
	&& usermod --append --groups rubygems vscode \
	&& chgrp -R rubygems "$GEM_HOME" \
	&& chmod -R g+rwX "$GEM_HOME" \
	&& find "$GEM_HOME" -type d -exec chmod g+s {} +
