# Flux manifest factorization

Flux has introduced a way to factorize your manifests, meaning it is now possible to fine tune how flux deploy manifests or update the manifests in the repo.  
The entrypoint is a `.flux.yaml` file that work on the consepts of `generators` (factorize and deploy) and `updaters` (factorize and update repo) that instructs flux which commands to run, the order and which context (cluster, repo). A command can be any command available to the shell in the flux container, and by default `kustomize` and `kubectl` are available along with a small list of unix tools.  

It is important to note that 
- If Flux finds a `.flux.yaml` file then it will only deploy the output from the `generators`
- The commands from both `generators` and/or `updaters` must result in emitting a yaml that flux can operate on

The major benefit from all this, besides being able to organize manifests better using kustomize, is that we can now provide flux deployments with values found outside of the namespace of what we want to deploy. This "values must be in the same namespace" is a major limitiation for using flux `helmRelease` along with `valuesFrom` functionality.

## Docs

- [fluxcd - manifest factorization](https://github.com/fluxcd/flux/blob/master/docs/references/fluxyaml-config-files.md)
- [Kustomize](https://kustomize.io/)
- [Declarative Management of Kubernetes Objects Using Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)

## How to find what tools that are available in the flux container

There are two ways:
1. _Inspect the [flux docker file](https://github.com/fluxcd/flux/blob/master/docker/Dockerfile.flux)_  
  
1. _Get a shell to the running flux container_      
  Explore the flux container in a test cluster and see what is available.  
  Example:
  ```sh
  # Test to see if flux image has gawk installed as they say per dockerfile
  which gawk
  # Expected output:
  /usr/bin/gawk
  ```

I found the second option to be the "safest" alternative as this is the version of flux you currently got running in your clusters.
I found it hard to figure out which version of flux dockerfile is the base for the current flux helm chart version, and so I ran into differences.  
Fex I could not find `gawk` as specified in the dockerfile, but I could find `awk` when looking in the running container.  


## Examples

_Prerequisite:_ Flux has been installed with (helm parameter) `--set manifestGeneration=true` in order to enable flux manifest factorization.

###  Using unix tools

_Scenario:_  
Here we want flux to deploy `my-resource-manifest.yaml`. Before it does so we want to change some things ("factorize") using pure unix tools, and then we emit the result to flux.  
Note that this example is not a smart way of actually changing a property in the manifest, it just a way of demonstrating that the command can be a shell command.

`repo/configs/my-resource-manifest.yaml`:
```sh
apiVersion: v1
kind: ConfigMap
data:
  message: "All Hail Megatron!"
```

`repo/configs/.flux.yaml`:
```sh
version: 1
commandUpdated:
  generators:
    - command: (echo -e "metadata:\n  name: demo")>> my-resource-manifest.yaml   # Add a name to the manifest
    - command: echo my-resource-manifest.yaml                                    # Emit result to flux
```

### Using kustomize

_Scenario:_  
We want to deploy 2 resources, and we have configured a `kustomize` file for how we want to factorize our manifests and in which order they should be deployed.

`repo/configs/demo-namespace.yaml`:
```sh
apiVersion: v1
kind: Namespace
metadata:
  name: demo
```

`repo/configs/resource-1.yaml`:
```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: "resource-1"
  namespace: demo  
data:
  message: "Hail Hydra!"
```

`repo/configs/resource-2.yaml`:
```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: "resource-2"
  namespace: demo  
data:
  message: "Beware green men"
```

`repo/configs/kustomization.yaml`:
```sh
resources:
- resource-1.yaml
- resource-2.yaml
```

`repo/configs/.flux.yaml`:
```sh
version: 1
commandUpdated:
  generators:
    - command: kustomize build . # Instruct flux to use kustomize to factorize the manifests and emit the result to flux
```

### Combining unix tools and kustomize in .flux.yaml

_Scenario:_  
Say we have some shared values that we would like to provide to all components during installation.  
We have many clusters that share the same configuration in a flux repo.  
Some of the components we want to deploy require a cluster unique value, say `clusterName`, and this value cannot be provided by the shared configuration.  

As a prerequisite for such deployments we can create a configmap, `cluster-config.yaml`, as a store for these values when we create the cluster:
```sh
apiVersion: v1
data:
  platform: |
    dnsZone: "dev.radix.equinor.com"
    appAliasBaseURL: "app.dev.radix.equinor.com"
    imageRegistry: "demo.azurecr.io"
    clusterName: "fancy-pants"
    clusterType: "development"
kind: ConfigMap
metadata:  
  name: "cluster-config"
  namespace: default
```

When we deploy our components we want flux to 
1. read values from `cluster-config.yaml` found in `default` namespace, 
1. inject the values into our component manifest and 
1. deploy the transformed manifests in a desired order

`repo/configs/demo-namespace.yaml`:
```sh
apiVersion: v1
kind: Namespace
metadata:
  name: demo
```

`repo/configs/resource-1.yaml`:
```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: "resource-1"
  namespace: demo  
data:
  cluster: "${clusterName}"
```

`repo/configs/resource-2.yaml`:
```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: "resource-1"
  namespace: demo  
data:
  host: "${clusterName}"
  containerRepo: "${imageRegistry}"
```

`repo/configs/kustomization.yaml`:
```sh
resources:
- resource-1.yaml
- resource-2.yaml
```

`repo/configs/.flux.yaml`:
```sh
version: 1
commandUpdated:
  generators:
    - command: >-
        kubectl get cm cluster-config -o jsonpath='{.data.platform}' > ./cluster-config.yaml # Read and store contents of cluster-config as yaml
    - command: >-
        awk 'BEGIN{print"#!/bin/sh"}1{sub(/: /,"=")}1{print "export "$0}' ./cluster-config.yaml > ./cluster-config.sh && chmod +x ./cluster-config.sh # Transform cluster-config yaml to shell environment variables
    - command: >-
        $(source ./cluster-config.sh  && (echo "#!/bin/sh"; echo "cat <<EOF >result.yaml"; cat ./resource-1.yaml; echo "EOF";)>tmp_heredoc.sh && source ./tmp_heredoc.sh && rm ./tmp_heredoc.sh && mv ./result.yaml ./resource-1.yaml) # Transform resource-1 manifest using a heredoc to inject the env vars, and do so in a subshell to avoid polluting the main flux shell
    - command: >-
        $(source ./cluster-config.sh  && (echo "#!/bin/sh"; echo "cat <<EOF >result.yaml"; cat ./resource-2.yaml; echo "EOF";)>tmp_heredoc.sh && source ./tmp_heredoc.sh && rm ./tmp_heredoc.sh && mv ./result.yaml ./resource-2.yaml) # Transform resource-2 manifest using a heredoc to inject the env vars, and do so in a subshell to avoid polluting the main flux shell
    - command: kustomize build . # Instruct flux to use kustomize to factorize the transformed manifests and emit the result to flux
```

### Combining unix tools and kustomize in .flux.yaml - Using script files

The previous example can be cleaned up by moving most of the shell script into a separate script file, and then call that script from the generator command.  
See [demos - factorization](./demos/factorization/) for how this can be set up.