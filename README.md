# radix-flux - k8s GitOps
This is the initial attempt at gitops for the radix platform using [Flux](https://github.com/weaveworks/flux/).  
We will start with the radix-operator, and if successfull, transition more components to be managed from this repo.

Official docs:
- https://github.com/weaveworks/flux/
- https://github.com/fluxcd/flux/blob/master/site/helm-integration.md
- https://www.weave.works/blog/managing-helm-releases-the-gitops-way

## How it works

A Flux controller runs inside the cluster. It is configured to watch a specific repo and branch.  
When we commit a yaml file to that repo/branch then Flux will apply that file to the cluster. Think of it as automated `kubectl apply -f $filename`.  

### Flux + helm
By default Flux will deploy any `*.yaml` it can find in the repo/branch it is set to watch, with the exception of anything that might look like a helm chart.  
You instruct Flux which helm charts to deploy and how by using a flux [helmRelease](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md) manifest. Flux will then create a corrensponding `helmRelease` custom resource in the cluster that is handled by the Flux helm operator. The Flux helm operator then deploy the helm chart as specified by the `helmRelease` resource. It is important to note that each flux `helmRelease` resource owns the corrensponding helm `release` in the cluster.

### Flux + container registry
Flux will also scan the container registry for any change based on a image filter in the manifests it watches.  
These filters can then trigger Flux to automatically update the manifests with new image in the config repo and then deploy the updated manifest to the cluster.   
We can control this behaviour by using [flux annotations](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md#using-annotations-to-control-updates-to-helmrelease-resources) in the manifests.


## How we use it

This repo contains the configurations for all cluster environments, where each environment corrensponds to a git branch and a directory.  

### Environments

- `production`  
  Git branch: `release`  
  Directory: `./production-configs/`  
  Configs for all production clusters  

- `development`  
  Git branch: `master`  
  Directory: `./development-configs/`  
  Configs for all development clusters, ie `weekly-*`, `playground-*`  


## Naming conventions and file structure

The name of any manifest should use the format `{name-of-resource}.yaml`

- `README.md`  
  It should always have up-to-date information for the configuration of the corrensponding branch/environment.  
- `/charts/`  
  Contains all helm charts we want flux to deploy.  
  We instruct Flux which charts to deploy and how by using a flux `helmRelease` manifest stored in a different folder.
- `/development-configs/`  
  Hold all configs that should be deployed into clusters in development environment  
  - `/radix-platform/`  
    Holds all the radix manifests we want flux to control.  
    This can be any type of k8s resource manifest or a helm chart in the form of a flux `helmRelease` manifest.  
- `/production-configs/`  
  Hold all configs that should be deployed into clusters in production environment. It should have the structure as the `/development-configs/` directory


## Development flow

1. Test your changes in branch `master`, in directory `/development-configs/`
1. When satisifed add your production changes into directory `/production-configs/` (remember to verify container registry, image filters etc)
1. When ready to release to production, create a pull request to branch `release` and run code review
1. When merge is complete, verify production cluster state


### How to update manifest image

If the manifest use flux [image filter](https://github.com/weaveworks/flux/blob/master/site/fluxctl.md#using-annotations) then all you have to do is to simply build, tag and push your image to the container registry.  
Flux will then update the manifests in the config repo if it can match the manifest image filter to the new image tag, and then it will deploy the updated manifest.

Example:  
- Manifests in `development` clusters will have a flux image filter annotation that match `glob:master-*`
- Manifests in `production` clusters will have a flux image filter annotation that match `glob:release-*`  


### How to delete manifest in cluster, keep manifest in config repo

1. In config repo/branch, add the annotation `flux.weave.works/ignore: true` to the manifest you want Flux to ignore
1. In cluster, delete the manifest  
   If this is a `helmRelease` manifest then you must delete the corrensponding `helmRelease` custom resource in the cluster.  
   This will then delete the corrensponding helm release.


### How to delete manifest in cluster and config repo

1. In config repo/branch, delete the manifest
1. In cluster, delete the manifest
   If this is a `helmRelease` manifest then you must delete the corrensponding `helmRelease` custom resource in the cluster.  
   This will then delete the corrensponding helm release.
  
