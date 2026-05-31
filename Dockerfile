# syntax=docker/dockerfile:1

# ---- build stage ----
# Base pinned by digest (stretch: reproducible base — a moving tag like
# :1.24 can change under you; the digest can't). See PROMPTS.md.
FROM golang:1.24@sha256:d2d2bc1c84f7e60d7d2438a3836ae7d0c847f4888464e7ec9ba3a1339a1ee804 AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
# CGO off + static link so the binary has no libc dependency and can run
# on an empty 'scratch' base. -s -w drops debug info to shrink it further.
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /main main.go

# ---- final stage ----
# scratch is the empty base: the final image is just the static binary
# (~10MB), which clears the < 50MB stretch check.
FROM scratch
COPY --from=build /main /app/main
EXPOSE 4444
ENTRYPOINT ["/app/main"]
