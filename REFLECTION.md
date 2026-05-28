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

What I still don't fully get is the SSH side of Jenkins. The
credentials plugin, private key vs passphrase, how agents authenticate,
it all kind of blurs together for me.

I asked the agent why everyone references credentials by ID in the
Jenkinsfile instead of pasting the secret directly. The thing I didn't
realise: Jenkins only hides secrets in the build log when they come
through the credentials plugin. If you write them as plain strings
they just show up in the log for anyone with build access.
