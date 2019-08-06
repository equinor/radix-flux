# radix-flux - k8s GitOps

This is the initial attempt at gitops for the radix platform using [Flux](https://github.com/weaveworks/flux/).  
We will start with the radix-operator, and if successfull, transition more components to be managed from this repo.

_Radix flux docs:_
- [How to flux](./how-to.md)
- [Known issues](./known-issues.md)
- [Radix platform components](https://github.com/equinor/radix-private/blob/master/docs/radix-platform/readme.md)

_Official docs:_
- [Weavework Flux](https://github.com/fluxcd/flux)
- [Weavework Flux - Helm operator](https://github.com/fluxcd/flux#get-started-with-the-helm-operator)


## How it works

A Flux controller runs inside the cluster. It is configured to watch a specific repo and branch.  
When we commit a yaml file to that repo/branch then Flux will apply that file to the cluster. Think of it as automated `kubectl apply -f $filename`.  

### Flux + helm

By default Flux will deploy any `*.yaml` it can find in the repo/branch it is set to watch, with the exception of anything that might look like a helm chart.  
You instruct Flux which helm charts to deploy and how by using a flux [helmRelease](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md) manifest. Flux will then create a corrensponding `helmRelease` custom resource in the cluster that is handled by the Flux helm operator. The Flux helm operator then deploy the helm chart as specified by the `helmRelease` resource. It is important to note that each flux `helmRelease` resource owns the corrensponding helm `release` in the cluster.  
Deleting a flux `helmRelease` will trigger the flux-helm-operator to delete and purge the corrensponding helm release.

### Flux + container registry

Flux will also scan the container registry for any change based on a image filter in the manifests it watches.  
These filters can then trigger Flux to automatically update the manifests with new image in the config repo and then deploy the updated manifest to the cluster.   
We can control this behaviour by using [flux annotations](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md#using-annotations-to-control-updates-to-helmrelease-resources) in the manifests.


## How we use it

### Configs per cluster environment

- `production`  
  Git branch: `release`  
  Directory: `./production-configs/`  
  Configs for all production clusters  

- `playground`  
  Git branch: `release`  
  Directory: `./playground-configs/`  
  Configs for all playground clusters, ie `playground-*`  

- `development`  
  Git branch: `master`  
  Directory: `./development-configs/`  
  Configs for all development clusters, ie `weekly-*`  

### Dependency on pre-installed config and secrets in cluster

In order to ease installation and use of radix components, and to not have to repeat the same values for every installation, we have moved some of the shared information and credentials out of the radix-operator chart and into "shared" configMap and secrets.

- ConfigMap: `radix-platform-config`
- Secret: `radix-docker` 
- Secret: `radix-sp-acr-azure`  

These are created by the [install_base_components.sh](https://github.com/equinor/radix-platform/blob/master/scripts/install_base_components.sh) script.

## Development flow

### Step 1: Test configuration in development

1. Tweak, add or remove configs in development directory in branch `master`

Flux running in development clusters will automatically deploy these changes when it discover a change in the corrensponding directory and branch.  
If you are testing major changes then consider creating your own cluster and set it to sync configs from a feature branch.

### Step 2: Release to QA/Playground

1. Create a feature-branch from `master`
1. Update configs in playground directory
1. Verify that container registry (radixdev/radixprod) and image filters are correct
1. Create a pull request to merge feature-branch into branch `master`, run code review
1. If review is ok, merge `master` to `release`  
   ```sh
   git checkout release
   git pull
   git merge master
   git push
   ```

Flux running in playground clusters will automatically deploy these changes when it discover a change in the corrensponding directory and branch.

### Step 3: Release to production

Repeat the same instructions as for Playground, update configs in production directory.  
Flux running in production clusters will automatically deploy these changes when it discover a change in the corrensponding directory and branch.

   
  
