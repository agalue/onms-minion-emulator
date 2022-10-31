FROM golang:1.19 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download -x

ADD ./ /app/
RUN apt update && \
    apt install librdkafka-dev libbsd-dev -y && \
    CGO_ENABLED=1 GOOS=linux go build -o minion-emulator .

FROM debian:11

COPY --from=builder /app/minion-emulator /usr/local/bin/minion-emulator

RUN apt update && \
    apt install librdkafka++1 libcap2-bin dnsutils -y && \
    groupadd minion && \
    useradd -g minion -r -s /bin/bash minion && \
    setcap cap_net_raw+ep /usr/local/bin/minion-emulator

USER minion
LABEL maintainer="Alejandro Galue <agalue@opennms.com>" name="OpenNMS Minion Emulator"

ENTRYPOINT [ "/usr/local/bin/minion-emulator" ]
