# Debug — `exec format error` running the pushed image on x86_64

**Scenario.** I built the image on an Apple Silicon Mac with a plain
`docker build -t ttl.sh/<name>:2h .` and pushed it. Build green, push
green, and on the x86_64 `docker` VM the manifest pulls fine. But
`docker run …` prints:

```
exec /app/main: exec format error
```

The container starts and dies immediately on that one line.

## Hypotheses (ranked)

1. **The image was built for `linux/arm64`.** A plain `docker build` on
   Apple Silicon stamps the builder's native architecture into the image
   config *and* compiles an arm64 Go binary inside it. An x86_64 kernel
   can't exec an aarch64 ELF, so the process dies the instant it starts —
   which is exactly "starts, then `exec format error`".
2. **The image config says amd64 but the binary inside is arm64.** "The
   image" carries arch in two independent places — the config/manifest
   metadata and the actual ELF bytes of `/app/main`. If `GOARCH` was set
   to arm64 while the base/platform stayed amd64, the manifest would look
   right while the binary still refuses to exec.

## Verification

1. Ask what architecture the image declares:
   `docker image inspect ttl.sh/<name>:2h --format '{{.Architecture}}'`
   (or `docker manifest inspect` against the registry). `arm64` confirms
   hypothesis 1.
2. Pull the binary out and look at the ELF itself (scratch has no shell to
   run `file` inside): `docker create --name x ttl.sh/<name>:2h &&
   docker cp x:/app/main ./main && file ./main`. `ARM aarch64` vs
   `x86-64` tells you whether the *binary* disagrees with the manifest
   (hypothesis 2) or matches it (hypothesis 1).

## Fix

Build for the architecture the deploy host actually runs. With buildx,
target the host platform explicitly and push in one step:

```
docker buildx build --platform linux/amd64 -t ttl.sh/<name>:2h --push .
```

(Equivalently, force the compiler with `GOARCH=amd64 CGO_ENABLED=0 GOOS=linux
go build` in the build stage.) Building multi-arch
`--platform linux/amd64,linux/arm64` makes the image run on either host.

## Lesson

"The image is built" only promises it runs on a host of the **same CPU
architecture (and OS)** it was built for — a container image is
arch-specific bytes, not a magically portable artifact, unless you
deliberately build a multi-arch manifest.
