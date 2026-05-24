# Debug — GLIBC mismatch on Ubuntu 18.04

**Error**

```
./main: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by ./main)
```

## Hypotheses (ranked)

1. **Build host has a newer GLIBC than the target.** The Jenkins machine runs
   a recent Ubuntu (22.04+, GLIBC 2.35+), so its `libc.so.6` exports
   `GLIBC_2.34`. Ubuntu 18.04 ships GLIBC 2.27, which doesn't. The binary was
   linked against symbols that simply don't exist on the customer's VM.
2. **The binary is dynamically linked through cgo when it didn't need to be.**
   Go's `net` package uses cgo for DNS resolution by default on Linux, which
   drags in libc. A pure-Go build wouldn't depend on the host's libc at all
   and wouldn't care which Ubuntu it runs on.

## Verification

1. On the customer VM, run `ldd --version` (expect 2.27 on Ubuntu 18.04).
   On the build host, run `ldd --version` (expect 2.35+). If the gap straddles
   2.34, hypothesis 1 is confirmed.
2. On the build host, run `file ./main` and `ldd ./main`. If the output says
   "dynamically linked" and lists `libc.so.6`, cgo is in play and hypothesis 2
   is the real lever — rebuilding without cgo will remove the dependency
   entirely, regardless of which GLIBC the build host has.

## Fix

Rebuild with cgo disabled so the binary doesn't link against the host's libc
at all:

```
CGO_ENABLED=0 go build -o main main.go
```

`ldd ./main` should now print `not a dynamic executable`. The binary then
runs on Ubuntu 18.04, 20.04, Alpine, or anything with a Linux kernel — no
libc required, no GLIBC version to match.

## Lesson

A Go binary is only as portable as its weakest dynamic dependency: by default
`net` pulls in cgo, which links against the build host's libc and silently
inherits its minimum GLIBC version. Ship with `CGO_ENABLED=0` (or build
inside a container whose libc matches the oldest target distro) whenever the
binary leaves the machine that built it.
