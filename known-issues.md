# Known issues

## external-dns

The secret must be preinstalled in the cluster.


## Kustomize

Regarding kustomize vars,  
they are not meant for arbitrary substitution. Kustomize has a hardcoded list for where substitution is allowed (...they have their reasons...), any deviations in your yaml is simply not touched at all, and you will not get any error/warnings from kustomize.
https://github.com/kubernetes-sigs/kustomize/issues/486

Have a look at their section for [Eschewed features](https://github.com/kubernetes-sigs/kustomize/blob/master/docs/eschewedFeatures.md) on why not some feature is implemented.
