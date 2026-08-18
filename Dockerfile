FROM haskell:9.10.3-slim-bookworm AS build

WORKDIR /app

COPY . /app

RUN mkdir /app/out && cabal install --installdir=/app/out

