# Build stage 0
FROM erlang:28.3.1.0-alpine

# Set working directory
RUN mkdir /buildroot
WORKDIR /buildroot

# Copy our Erlang test application
COPY . .
RUN apk add --update git

RUN rebar3 release

# Build stage 1
FROM alpine

# Install some libs
RUN apk add --no-cache openssl && \
    apk add --no-cache ncurses-libs  && \
    apk add --no-cache libstdc++ && \
    apk add --no-cache libgcc

# Install the released application
COPY --from=0 /buildroot/_build/default/rel/ldf /ldf

CMD ["/ldf/bin/ldf", "foreground"]