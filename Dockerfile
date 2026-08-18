FROM alpine:3.20 AS build

WORKDIR /app

RUN apk add \
    ghc \
    cabal \
    musl-dev \
    gmp-dev \
    zlib-dev \
    zlib-static \
    ncurses-dev \
    ncurses-static \
    build-base

COPY . /app

RUN mkdir -p /app/out && cabal update

RUN cabal install \
    --installdir=/app/out \
    --install-method=copy \
    --disable-executable-dynamic \
    --ghc-options="-optl-static -optl-pthread"

FROM scratch
COPY --from=build /app/out/mc-config /mc-config

ENTRYPOINT ["/mc-config"]
