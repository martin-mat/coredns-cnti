# CoreDNS, the CNTi way

A sample deployment of [CoreDNS](https://coredns.io) that passes every
[CNTi Test Suite](https://github.com/lfn-cnti/testsuite) certification (`cert`) test,
checked on every change by the
[CNTi Test Suite GitHub Action](https://github.com/lfn-cnti/testsuite-action).

![CNTi](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/martin-mat/ccb9cc476b5852d93c51a2feb4f9d44e/raw/cnti_badge.json)

## What differs from stock CoreDNS

Stock CoreDNS (official image + [upstream Helm chart](https://github.com/coredns/helm)) fails
three essential CNTi tests. This repository fixes them without forking either:

| CNTi test | Problem | Fix |
|---|---|---|
| `specialized_init_system` | CoreDNS runs as PID 1 | [`Dockerfile`](Dockerfile): [tini](https://github.com/krallin/tini) is PID 1 and execs `/coredns` |
| `zombie_handled` | PID 1 does not reap orphaned children | same — tini reaps zombies |
| `non_root_containers` | The image runs as uid 65532, but the manifest does not say so | [`cnti-testsuite.yaml`](cnti-testsuite.yaml): `podSecurityContext.runAsNonRoot/runAsUser/runAsGroup` |

The image is upstream's `distroless/static:nonroot` layout with tini added. Both `/tini` and
`/coredns` carry the `cap_net_bind_service` file capability: the chart runs the container with
`allowPrivilegeEscalation: false` (no_new_privs), under which an exec cannot gain a capability
the caller does not already hold — so tini must hold it for coredns to bind port 53 as uid 65532.
(Upstream needs it only on `/coredns` because runc execs the binary directly.)

## Layout

- `Dockerfile` — builds `ghcr.io/martin-mat/coredns-cnti:<coredns version>`
- `cnti-testsuite.yaml` — CNTi config: upstream chart `coredns/coredns` 1.47.0 with `--set`
  overrides for the image and the security context (`COREDNS_IMAGE_TAG` picks the tag)
- `.github/workflows/cnti.yml` — builds the image, loads it into the action's kind cluster,
  runs the CNTi action against it and requires all essential tests to pass; only a certified
  image is pushed (on `main`)

## Run it yourself

```bash
docker build -t ghcr.io/martin-mat/coredns-cnti:1.14.6 .
# with a kind cluster: kind load docker-image ghcr.io/martin-mat/coredns-cnti:1.14.6
cnti-testsuite setup
cnti-testsuite cnf_install --cnf-config cnti-testsuite.yaml
cnti-testsuite cert
```
