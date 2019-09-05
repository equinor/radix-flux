# Known issues

## external-dns

The secret must be preinstalled in the cluster.

## kured

[Weaveworks](https://www.weave.works/) decided to move their Docker images from `quay.io` to `docker.io`.
However, the current version of the helm chart (`1.1.1`) still points to a Docker image hosted on `quay.io`. To solve this issue, in the `HelmRelease` file a line should be added to override the default URL, as follows.

```
image.repository: "docker.io/weaveworks/kured"
```

This may not be necessary in future releases of the helm charts.

References:
- https://github.com/weaveworks/kured/issues/68
- https://github.com/MicrosoftDocs/azure-docs/issues/30144

## Kustomize

Regarding kustomize vars,  
they are not meant for arbitrary substitution. Kustomize has a hardcoded list for where substitution is allowed (...they have their reasons...), any deviations in your yaml is simply not touched at all, and you will not get any error/warnings from kustomize.
https://github.com/kubernetes-sigs/kustomize/issues/486

Have a look at their section for [Eschewed features](https://github.com/kubernetes-sigs/kustomize/blob/master/docs/eschewedFeatures.md) on why not some feature is implemented.