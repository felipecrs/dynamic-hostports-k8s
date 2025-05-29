ARG KUBECTL_VERSION="1.29.15"
FROM registry.k8s.io/kubectl:v${KUBECTL_VERSION} AS kubectl

FROM golang:1.24 AS build
WORKDIR /src
COPY src/go.mod src/go.sum ./
RUN go mod download
COPY src .
RUN go build -o main .

FROM scratch AS rootfs

COPY --from=build /src/main /app/
COPY --from=build /src/get_node_fqdn.sh /app/
COPY --from=kubectl /bin/kubectl /usr/local/bin/kubectl

FROM ubuntu:noble
RUN useradd --system --no-create-home user
USER user
COPY --from=rootfs / /
ENV FQDN_IMAGE="ubuntu:noble"
WORKDIR /app
CMD ["./main"]
