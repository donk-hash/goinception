FROM golang:1.22-alpine AS builder

ENV TZ=Asia/Shanghai
ENV LANG="en_US.UTF-8"

RUN apk add --no-cache \
    ca-certificates wget \
    make \
    git \
    gcc \
    musl-dev

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /goInception ./tidb-server/main.go

RUN wget -q -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 \
 && chmod +x /usr/local/bin/dumb-init
# COPY bin/percona-toolkit.tar.gz /tmp/percona-toolkit.tar.gz
COPY bin/pt-online-schema-change /tmp/pt-online-schema-change
COPY bin/gh-ost /tmp/gh-ost
COPY config/config.toml.default /etc/config.toml

# Executable image
FROM alpine

COPY --from=builder /goInception /goInception
COPY --from=builder /etc/config.toml /etc/config.toml
COPY --from=builder /usr/local/bin/dumb-init /usr/local/bin/dumb-init

# COPY --from=builder /tmp/percona-toolkit.tar.gz /tmp/percona-toolkit.tar.gz
COPY --from=builder /tmp/pt-online-schema-change /usr/local/bin/pt-online-schema-change
COPY --from=builder /tmp/gh-ost /usr/local/bin/gh-ost

WORKDIR /

EXPOSE 4000

ENV LANG="en_US.UTF-8"
ENV TZ=Asia/Shanghai

# ENV PERCONA_TOOLKIT_VERSION 3.0.4

# && wget -O /tmp/percona-toolkit.tar.gz https://www.percona.com/downloads/percona-toolkit/${PERCONA_TOOLKIT_VERSION}/source/tarball/percona-toolkit-${PERCONA_TOOLKIT_VERSION}.tar.gz \

#RUN set -x \
#  && apk add --no-cache perl perl-dbi perl-dbd-mysql perl-io-socket-ssl perl-term-readkey make tzdata \
#  && tar -xzvf /tmp/percona-toolkit.tar.gz -C /tmp \
#  && cd /tmp/percona-toolkit-${PERCONA_TOOLKIT_VERSION} \
#  && perl Makefile.PL \
#  && make \
#  && make test \
#  && make install \
#  && apk del make \
#  && rm -rf /var/cache/apk/* /tmp/percona-toolkit*


RUN set -x \
  && apk add --no-cache perl perl-dbi perl-dbd-mysql perl-io-socket-ssl perl-term-readkey tzdata \
  && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
  && chmod +x /usr/local/bin/pt-online-schema-change \
  && chmod +x /usr/local/bin/gh-ost

ENTRYPOINT ["/usr/local/bin/dumb-init", "/goInception","--config=/etc/config.toml"]
