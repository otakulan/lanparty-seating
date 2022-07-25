FROM alpine

# Set exposed ports
EXPOSE 4000
ENV PORT=4000 MIX_ENV=prod

RUN apk add --update-cache \
    elixir \
    nodejs \
    npm \
  && rm -rf /var/cache/apk/*

# Cache elixir deps
ADD mix.exs mix.lock ./
RUN mix local.hex --force \
  mix local.rebar --force \
  mix do deps.get, deps.compile

# Same with npm deps
ADD assets/package.json assets/
RUN cd assets && \
    npm install

ADD . .

# Run frontend build, compile, and digest assets
RUN cd assets/ && \
    npm install && \
    cd - && \
    mix do compile, phx.digest

USER default

CMD ["mix", "phx.server"]
