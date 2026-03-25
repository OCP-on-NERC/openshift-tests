# Test image

This is a standard alpine image to which we have added the `whoami` service from `docker.io/traefik/whoami`.

To build the image:

```
podman build -t ghcr.io/ocp-on-nerc/openshift-tests:latest image
```
