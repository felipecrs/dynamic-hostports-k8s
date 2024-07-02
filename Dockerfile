FROM golang:1.22-alpine AS builder
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

FROM alpine
RUN adduser --system --no-create-home user
USER user

ENV FQDN_IMAGE="ubuntu:noble"

WORKDIR /app
COPY --from=kubectl /kubectl /usr/local/bin/kubectl
COPY --from=builder /src/main /app/
CMD ["./main"]
