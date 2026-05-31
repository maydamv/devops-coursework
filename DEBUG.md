# Debug — app unreachable after the pipeline goes green

**Scenario.** The pipeline is green and the "Copy + run on target" stage
logs say it succeeded. From my laptop, `curl <target>:4444` returns
`Connection refused`. I SSH into target, run `./main` in the foreground —
it works, and `curl localhost:4444` returns the JSON. The moment I `exit`
the SSH session, the app dies. The next pipeline run behaves the same way.

## Hypotheses (ranked)

1. **The app was started as a child of the SSH session, so it dies on
   logout (SIGHUP).** A run step like `ssh target './main &'` leaves the
   process in that session's process group; when the connection closes the
   kernel sends SIGHUP and the app exits. This is the strongest fit — the
   app provably lives only as long as the session, which is the one symptom
   the scenario states outright.
2. **The app binds to `127.0.0.1` instead of all interfaces.** If it
   listened on loopback only, `curl localhost:4444` on target would work
   while `curl <target>:4444` from the laptop got `Connection refused` —
   even with the process perfectly alive. This explains the remote refusal
   without invoking process death, so it has to be ruled out separately.

## Verification

1. Right after a pipeline run (no interactive session open), check whether
   anything is alive: `ssh target 'pgrep -af main'`. An empty result means
   the process did not survive the run — confirms hypothesis 1.
2. While the app is running, inspect what address it's bound to:
   `ssh target 'ss -ltnp | grep :4444'`. `127.0.0.1:4444` points to
   hypothesis 2 (loopback-only); `0.0.0.0:4444` or `*:4444` clears the
   binding and sends you back to hypothesis 1.

## Fix

Hypothesis 1 is the real cause, so stop starting the binary inside the SSH
session and let `systemd` own it:

```
sudo install -m 0644 myapp.service /etc/systemd/system/myapp.service
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
```

systemd starts the process in its own cgroup, detached from any login
session, so closing SSH no longer touches it, and `Restart=on-failure`
brings it back if it crashes. (If verification had pointed at hypothesis 2
instead, the minimal fix is binding the server to `:4444` / `0.0.0.0`
rather than `127.0.0.1` — which the Go source already does.)

## Lesson

"Process exists right now" means something you launched is running this
instant, still tethered to the terminal that started it; "process is
supervised" means an init system owns it independently of any session and
keeps it alive — and only the second one is what "deployed" should mean.
