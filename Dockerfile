# BUILDER
FROM golang:1.21 AS builder

RUN apt-get update && apt-get upgrade -y &&\
  mkdir -p /var/lib/sqlite

WORKDIR /go/src/github.com/ory/kratos

COPY go.mod go.mod
COPY go.sum go.sum
COPY internal/httpclient/go.* internal/httpclient/
COPY internal/client-go/go.* internal/client-go/

ENV GO111MODULE on
ENV CGO_ENABLED 1
ENV CGO_CPPFLAGS -DSQLITE_DEFAULT_FILE_PERMISSIONS=0600

RUN go mod download

COPY . .

ARG VERSION
ARG COMMIT
ARG BUILD_DATE

RUN --mount=type=cache,target=/root/.cache/go-build go build \
  -ldflags="-X 'github.com/ory/kratos/driver/config.Version=${VERSION}' -X 'github.com/ory/kratos/driver/config.Date=${BUILD_DATE}' -X 'github.com/ory/kratos/driver/config.Commit=${COMMIT}'" \
  -o /usr/bin/kratos

# RUNNER
FROM alpine:3.18.3

RUN addgroup -S ory; \
    adduser -S ory -G ory -D -u 10000 -h /home/ory -s /bin/nologin; \
    chown -R ory:ory /home/ory
RUN apk --update upgrade && apk --no-cache --update-cache --upgrade --latest add ca-certificates

WORKDIR /home/ory

COPY --from=builder --chown=ory:ory /usr/bin/kratos /usr/bin/kratos

# Exposing the ory home directory to simplify passing in Kratos configuration (e.g. if the file $HOME/.kratos.yaml
# exists, it will be automatically used as the configuration file).
VOLUME /home/ory

# Declare the standard ports used by Kratos (4433 for public service endpoint, 4434 for admin service endpoint)
EXPOSE 4433 4434

USER 10000

ENTRYPOINT ["kratos"]
CMD ["serve"]
