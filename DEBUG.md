# Debug — Pod stuck in ImagePullBackOff

**Scenario.** The pipeline pushes the image to `ttl.sh` and applies the Pod
manifest. `kubectl get pods` shows `ImagePullBackOff`. The `image:` field in
the manifest matches the tag the pipeline pushed, and on the Jenkins machine
`docker pull <image>` succeeds.

## Hypotheses (ranked)

1. **The ttl.sh tag expired before the kubelet pulled it.** `ttl.sh/...:2h`
   lives for ~2 hours; Jenkins `docker pull` succeeds because the image is
   still in Jenkins' *local* cache from the build, but the kubelet on the
   node has no cache and must fetch from ttl.sh — where, after the TTL, the
   tag is gone. The puller and its environment are different.
2. **The cluster node can't reach ttl.sh even though Jenkins can.** The
   kubelet pulls using the node's own network egress/DNS; if the node has no
   route to `ttl.sh` (or no DNS for it) the pull fails with a network error
   while Jenkins, on a different host with egress, pulls fine.

## Verification

1. `kubectl describe pod myapp` and read the Events. A pull error like
   `manifest unknown` / `not found` / HTTP 404 points to hypothesis 1 (the
   tag is gone). A `dial tcp: i/o timeout` or `no such host` points to
   hypothesis 2 (the node can't reach the registry).
2. Reproduce the pull from the node's runtime, not from Jenkins:
   `crictl pull ttl.sh/maydamv-cs411-devops:2h` on the node (or via a debug
   pod). If it 404s, the image is expired (1); if it times out, it's egress
   (2).

## Fix

Hypothesis 1 is the usual cause with `ttl.sh`. Push a fresh image
immediately before applying and force the kubelet to fetch it:

```
docker push ttl.sh/maydamv-cs411-devops:2h   # fresh, in the same pipeline run
# manifest:
imagePullPolicy: Always
```

So the node pulls the just-pushed image instead of relying on anything
cached. (If verification showed a *private* registry instead, the minimal
fix is `imagePullSecrets` on the Pod; if it showed a stale tag in the
manifest, correct the tag.)

## Lesson

"I can pull this image" means *my* host, with *my* network and possibly a
warm local cache, can fetch it right now; "the cluster can pull this image"
means every node's kubelet can fetch it fresh, with the node's own network
and credentials — and only the second one is what a Pod actually depends on.
