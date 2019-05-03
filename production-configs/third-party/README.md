# Third party components for PRODUCTION environment

## kured

[kured](https://github.com/weaveworks/kured) is a Kubernetes daemonset that performs safe automatic node reboots when the need to do so is indicated by the package management system of the underlying OS. By default it watches for the presence of a reboot sentinel `/var/run/reboot-required` in all nodes of a Kubernetes cluster.

### Known issues

[Weaveworks](https://www.weave.works/) decided to move their Docker images from `quay.io` to `docker.io`.
However, the current version of the helm chart (`1.1.1`) still points to a Docker image hosted on `quay.io`. To solve this issue, in the `HelmRelease` file a line should be added to override the default URL, as follows.

```
image.repository: "docker.io/weaveworks/kured"
```

This may not be necessary in future releases of the helm charts.

References:
- https://github.com/weaveworks/kured/issues/68
- https://github.com/MicrosoftDocs/azure-docs/issues/30144