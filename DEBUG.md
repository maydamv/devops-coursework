# Debug — external curl to EC2 hangs (not "connection refused")

**Scenario.** The pipeline shows SUCCESS. I SSH into the EC2 instance and
`curl localhost:4444` returns the expected JSON — the app is running. But
from my laptop, `curl http://<public-ip>:4444` **hangs forever** (not
"connection refused" — it just sits there until Ctrl-C).

The shape of the symptom is the clue: a *hang* means the SYN packet got no
reply at all (silently dropped), whereas "connection refused" would mean
the packet reached the host and something actively replied with a TCP RST.
So the app binding to the wrong address (which would give a RST → refused)
is ruled out — something in the network path is **dropping** the packets.

## Hypotheses (ranked)

1. **The Security Group has no inbound rule for tcp/4444.** AWS Security
   Groups default-deny and *drop* disallowed inbound packets with no
   response, so the client's SYN is swallowed and curl hangs and
   retransmits. This is the textbook cause of a hang on a fresh EC2.
2. **A subnet Network ACL (or a host firewall like ufw/iptables) is
   dropping 4444.** NACLs are stateless and easy to leave too tight, and
   they also drop rather than reject — same silent-hang symptom, just one
   layer further out (or in, for a host firewall).

## Verification

1. Check the SG inbound rules: AWS console → EC2 → the instance's Security
   Group → Inbound rules (or `aws ec2 describe-security-groups`). No
   `tcp/4444` entry confirms hypothesis 1. From the Jenkins box,
   `nc -vz <public-ip> 4444` timing out (vs an instant refuse) corroborates
   a drop.
2. Check the layers the SG doesn't cover: the subnet's NACL inbound/outbound
   rules in the console, and on the instance `sudo iptables -L -n` /
   `sudo ufw status`. A deny/absence there points to hypothesis 2.

## Fix

Add an inbound rule allowing `tcp/4444` from the source that needs it
(`0.0.0.0/0` for the verify step, or narrower):

```
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> --protocol tcp --port 4444 --cidr 0.0.0.0/0
```

(If verification pointed at the NACL or a host firewall instead, open 4444
there — no VPC rebuild needed.)

## Lesson

A **dropped** packet gets no reply, so the client waits and retransmits —
that's the *hang*; a packet that **reaches a closed port** gets a TCP RST
back, so the client fails instantly with *connection refused*. The symptom
shape tells you whether a firewall is silently in the path or the host is
actively saying "nothing's listening."
