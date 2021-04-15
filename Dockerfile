FROM golang:alpine AS builder
WORKDIR /app
ADD ./ /app/
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags musl -a -o minion-emulator

FROM alpine
COPY --from=builder /app/minion-emulator /usr/local/bin/minion-emulator
RUN apk add --no-cache libcap && \
    addgroup -S minion && \
    adduser -S -G minion minion && \
    setcap cap_net_raw+ep /usr/local/bin/minion-emulator
USER minion
LABEL maintainer="Alejandro Galue <agalue@opennms.org>" name="Minion Emulator"
ENTRYPOINT [ "/usr/local/bin/minion-emulator" ]
