# Reflection — introduction-to-builds

## What did I do?

I copied the 30-line `main.go` from the challenge brief into my repo,
ran `go build -o main main.go` on the iximiuz playground, started the
result with `./main &`, and confirmed the response with
`curl localhost:4444`. For the three stretch tasks I produced
`main-arm64` with `GOOS=linux GOARCH=arm64 go build`, a stripped build
with `-ldflags='-s -w'`, and a Sinatra port in `app.rb`. All three
landed under `~/app/` with the exact filenames iximiuz expects, so the
dashboard auto-ticked the stretches.

## What was most surprising?

The first surprise was practical: on a course literally called
"introduction to builds", the playground didn't have Go pre-installed.
My first build returned `bash: go: command not found` and I had to
`sudo apt-get install -y golang-go` before anything else worked. The
second surprise was how compact the program is for what it does — 30
lines of Go gives you a working HTTP server with JSON serialisation,
zero external dependencies. Coming from frontend work where a hello-
world needs a `package.json`, a bundler and a `node_modules` folder,
that felt almost suspicious. I also started writing a `Jenkinsfile` to
explore pipeline-as-code for the next challenge, which made the same
point from another angle: the build steps that produced this binary
are themselves describable as code, versioned alongside `main.go`.

## What's still unclear?

I built `main-arm64` and `main-stripped` to satisfy the stretch checks
but didn't actually inspect them — I never ran `file ./main-arm64` to
confirm the architecture, or `du -b` to measure how much smaller
stripping really makes a binary. I trusted the auto-tick and moved on.
The stretch is only meaningful if I know what I produced, not just
that a file with the right name exists.
