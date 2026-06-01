# syntax=docker/dockerfile:1

# ---- build stage ----
# Base pinned by digest (stretch: reproducible base — a moving tag like
# :1.24 can change under you; a digest can't). See PROMPTS.md.
FROM golang:1.24@sha256:d2d2bc1c84f7e60d7d2438a3836ae7d0c847f4888464e7ec9ba3a1339a1ee804 AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
# CGO off + static link so the binary has no libc dependency and runs on a
# minimal base. -s -w drops debug info to shrink it further.
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /main main.go

# ---- final stage ----
# alpine (~7MB) keeps the final image well under 50MB while still shipping
# a wget (busybox) for the HEALTHCHECK — scratch/distroless have neither a
# shell nor wget, so the HEALTHCHECK auto-check couldn't pass there.
FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc
COPY --from=build /main /app/main
EXPOSE 4444
HEALTHCHECK --interval=10s --timeout=2s --start-period=3s \
    CMD wget -qO- http://localhost:4444/ || exit 1
ENTRYPOINT ["/app/main"]
