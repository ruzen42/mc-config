FROM alpine:3.24 AS build

WORKDIR /app

RUN apk add \
    ghc \
    cabal \
    musl-dev \
    gmp-dev \
    gmp-static \
    zlib-dev \
    zlib-static \
    ncurses-dev \
    ncurses-static \
    build-base

RUN cabal update

COPY *.cabal cabal.project* /app/

RUN cabal build --only-dependencies \
    --disable-executable-dynamic \
    --ghc-options="-optl-static -optl-pthread"

COPY . /app

RUN mkdir -p /app/out

RUN cabal install \
    --installdir=/app/out \
    --install-method=copy \
    --disable-executable-dynamic \
    --ghc-options="-optl-static -optl-pthread"

FROM alpine:3.24
COPY --from=build /app/out/mc-config /mc-config

