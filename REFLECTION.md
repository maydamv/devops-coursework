# Reflection — first-deployment-pipeline

## What did I do?

I added the second half of the pipeline: take the binary the build stage
produces and actually run it on a different machine. The Jenkinsfile now
has four stages. **Build** compiles `main` on the Jenkins node. **Ship**
`scp`s the binary and a `myapp.service` unit file to the `target` machine
over SSH. **Deploy** SSHes in and installs both — it creates a dedicated
non-root `myapp` user, drops the binary into `/usr/local/bin` with
`install`, copies the unit into `/etc/systemd/system`, and runs
`daemon-reload` + `enable` + `restart` so systemd owns the process.
**Health check** polls `curl http://localhost:4444/` up to ten times and
fails the build if the JSON never appears. Authentication is a
`target-ssh` credential injected with `withCredentials`, never an inline
key.

## What was most surprising?

Three things, all the hard way. First, on a course about *builds*, the
Jenkins node had no Go at all — the first run died on `go: not found` and
I had to `apt-get install golang-go` before anything compiled. Second,
`sshagent` doesn't exist on this Jenkins: the build blew up with
`No such DSL method 'sshagent'` because the SSH Agent plugin isn't
installed, so I switched to `withCredentials([sshUserPrivateKey(...)])`,
which hands you a temporary key file you pass with `ssh -i`. Third, the
whole point of the systemd unit only clicked when I connected it to the
debug scenario: a binary you start over SSH is a child of that session
and dies with it, while a systemd-managed one keeps running after you log
out. "Deployed" and "currently running in my terminal" are not the same
thing.

## What's still unclear?

I fixed the die-on-logout problem with systemd, but I don't fully
understand the *mechanism*. I know a backgrounded SSH child gets SIGHUP
when the session closes, and that a systemd service somehow doesn't — but
I can't yet explain exactly what systemd does (its own cgroup? a fresh
session?) that detaches the process from the login session's lifecycle.
That's the gap between making the symptom go away and actually
understanding why the fix works.
