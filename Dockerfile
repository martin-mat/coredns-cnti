# CoreDNS image following CNTi best practices: upstream CoreDNS, run as a
# non-root user, with tini as PID 1 so signals are forwarded and zombie
# processes are reaped.
#
# Differences from https://github.com/coredns/coredns/blob/master/Dockerfile:
#   - tini (static) is added and used as the entrypoint
#   - the coredns binary is taken from the official image instead of a local build

ARG COREDNS_VERSION=1.14.6
ARG TINI_VERSION=v0.19.0
ARG DEBIAN_IMAGE=debian:stable-slim
ARG BASE=gcr.io/distroless/static-debian12:nonroot

FROM coredns/coredns:${COREDNS_VERSION} AS coredns

FROM ${DEBIAN_IMAGE} AS build
ARG TINI_VERSION
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update \
    && apt-get -qq --no-install-recommends install ca-certificates curl libcap2-bin
RUN curl -fsSL -o /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static \
    && curl -fsSL -o /tini.sha256sum https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static.sha256sum \
    && sed 's| tini-static| /tini|' /tini.sha256sum | sha256sum -c - \
    && chmod 0755 /tini
COPY --from=coredns /coredns /coredns
# File capabilities so a non-root coredns can still bind :53. tini needs it as
# well: with allowPrivilegeEscalation=false (no_new_privs) an exec may not gain
# capabilities the caller does not already hold, so the cap must be carried by
# tini for coredns to keep it.
RUN setcap cap_net_bind_service=+ep /coredns \
    && setcap cap_net_bind_service=+ep /tini

FROM ${BASE}
COPY --from=build /tini /tini
COPY --from=build /coredns /coredns
# Numeric uid/gid so Kubernetes can verify runAsNonRoot at admission.
USER 65532:65532
WORKDIR /
EXPOSE 53 53/udp
ENTRYPOINT ["/tini", "--", "/coredns"]
