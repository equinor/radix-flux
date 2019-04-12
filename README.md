# radix-flux - k8s GitOps
This is the initial attempt at gitops for the radix platform using [Flux](https://github.com/weaveworks/flux/).  
We will start with the radix-operator, and if successfull, transition more components to be managed from this repo.

## How it works
A Flux controller runs inside the cluster. It is configured to watch a specific repo and branch.  
When we commit a yaml file to that repo/branch then Flux will apply that file to the cluster. Think of it as automated `kubectl apply -f $filename`.  
Flux will deploy any `*.yaml` it can find in the repo/branch it is set to watch, with the exception of anything that might look like a helm chart.  
You instruct Flux which charts to deploy and how by using a flux [helmRelease](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md) manifest.  

Flux will also scan the container registry for any change based on a image filter in the manifests.  
We can control this behaviour by using [flux annotations](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md#using-annotations-to-control-updates-to-helmrelease-resources) in the manifests.

## How we use it
This repo contains the configurations for all cluster environments, where each environment corrensponds to a git branch.  
Branch `master` is kept clean for anything but initial documentation.  

### Production
Git branch: [production](https://github.com/equinor/radix-flux/tree/production)  
Configs for all production clusters.  

### Development
Git branch: [development](https://github.com/equinor/radix-flux/tree/development)  
Configs for all development clusters, ie `weekly-*`, `playground-*`.  


## Naming conventions and file structure

The name of any manifest should use the format `{name-of-resource}.yaml`

- `README.md`  
  It should always have up-to-date information for the configuration of the corrensponding branch/environment.
- `/docs`  
  Any additional documentation.
- `/charts`  
  Contains all helm charts we want flux to deploy.  
  We instruct Flux which charts to deploy and how by using a flux `helmRelease` manifest stored in a different folder.
- `/radix-platform`  
  Holds all the radix manifests we want flux to control.  
  This can be any type of k8s resource manifest or a helm chart in the form of a flux `helmRelease` manifest.  
  