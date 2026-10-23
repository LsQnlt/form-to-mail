FROM ruby:3.2-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --shell /usr/sbin/nologin app

WORKDIR /app

ENV BUNDLE_WITHOUT="test" \
    BUNDLE_FROZEN="true" \
    RACK_ENV="production" \
    PORT="3000"

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
USER app

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
