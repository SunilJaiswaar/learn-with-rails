# syntax=docker/dockerfile:1
#
# Production image. Build:
#   docker build -t codequest .
# Run:
#   docker run -e RAILS_MASTER_KEY=<key> -p 80:80 codequest
#
# Note on the code sandbox: learner code runs under bubblewrap, which needs
# unprivileged user namespaces. Grant them explicitly rather than running the
# container privileged, for example:
#   docker run --security-opt seccomp=unconfined ...
# Better still, run the runner as its own service on a host that allows
# user namespaces, and keep the web container without that capability.

ARG RUBY_VERSION=3.4.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 libvips postgresql-client bubblewrap && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ---- build stage -----------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# A dummy key is fine here: only the asset digest matters at build time.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ---- final stage -----------------------------------------------------------
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as an unprivileged user. bubblewrap still works, because unprivileged
# user namespaces do not require root.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "80"]
