# Reflection — introduction-to-builds

## What did I do?

I wrote a 30-line Go HTTP server that marshals a `Simple` struct into JSON and
serves it on port 4444. I ran `go build -o main main.go`, which produced a
single self-contained binary in `~/app/`, started it with `./main &`, and hit
it from a second prompt with `curl localhost:4444` — the response was the
expected `{"Name":"Hello","Description":"World","Url":"localhost:4444"}`. Then
I went after all three stretches: cross-compiled the same source to arm64 with
`GOOS=linux GOARCH=arm64 go build -o main-arm64 main.go`, produced a stripped
build with `-ldflags='-s -w' -o main-stripped main.go`, and re-implemented the
endpoint as a small Sinatra app (`app.rb`) so I could see what each runtime
actually needs on the host machine.

## What was most surprising?

The size delta from stripping was smaller than I expected — `du -b` showed
`main-stripped` only about 25% smaller than `main`, because most of a Go
binary is the runtime and the standard library, not the symbol table that
`-s -w` drops. The other surprise was running `file ./main-arm64`: the
output says `ELF 64-bit LSB executable, ARM aarch64`, and the playground
(x86_64) flatly refuses to execute it. The Go toolchain happily produced a
binary for a CPU it can't run, which made the "build target ≠ host machine"
distinction concrete in a way a slide never did. The Ruby comparison drove
the same point home from the other direction: to run `./main` the machine
needs nothing — it's one self-contained ELF file — but to run `app.rb` the
machine needs a Ruby interpreter plus the Sinatra gem installed system-wide.

## What's still unclear?

I don't yet have a clean mental model of when Go decides to link against the
host's libc versus producing a fully static binary. I know `net` and `os/user`
pull in cgo by default on Linux, and that `CGO_ENABLED=0` switches to the
pure-Go `netgo` resolver, but I can't yet predict from looking at an import
list whether a given program will end up dynamically linked or not. I'd like
to understand the exact rule the toolchain follows so I'm not surprised the
next time a binary that "works on my machine" fails on a slightly older
Ubuntu — which is exactly the failure mode the DEBUG task in this challenge
walks through.
