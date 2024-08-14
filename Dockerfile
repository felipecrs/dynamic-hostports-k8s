FROM golang:1.23 AS build
WORKDIR /src
COPY src/go.mod src/go.sum ./
RUN go mod download
COPY src .
RUN go build -o main .

FROM alpine AS kubectl

ARG KUBECTL_VERSION="1.30.2"
RUN apk add --no-cache curl \
    && curl -fsSL --output /kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod +x /kubectl

FROM scratch AS rootfs

COPY --from=build /src/main /app/
COPY --from=build /src/get_node_fqdn.sh /app/
COPY --from=kubectl /kubectl /usr/local/bin/kubectl

FROM ubuntu:noble
RUN useradd --system --no-create-home user
USER user
COPY --from=rootfs / /
ENV FQDN_IMAGE="ubuntu:noble"
WORKDIR /app
CMD ["./main"]
