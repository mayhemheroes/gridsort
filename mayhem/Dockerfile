FROM debian:bookworm as builder

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install build-essential clang -y

ADD . /gridsort
WORKDIR /gridsort/fuzz

RUN make

FROM debian:bookworm
COPY --from=builder /gridsort/fuzz/gridsort-fuzz /