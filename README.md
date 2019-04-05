# radix-flux
This is the initial attempt at gitops for the radix platform using [Flux](https://github.com/weaveworks/flux/).  
We will start with the radix-operator, and if successfull, transition more components to be managed from this repo.

## How it works
A Flux controller runs inside the cluster. It is configured to watch a specific repo and branch. When we commit a yaml file to that repo/branch then Flux will apply that file to the cluster. Think of it as automated `kubectl apply -f $filename`.

## How we use it
This repo contains the configurations for all cluster environments, where each environment corrensponds to a git branch.  
Branch `master` is kept clean for anything but initial documentation.  

### Production
Git branch [`production`](https://github.com/equinor/radix-flux/tree/production)  
Configs for all production clusters.  

### Development
Git branch [`development`](https://github.com/equinor/radix-flux/tree/development)  
Configs for all development clusters, ie `weekly-*`, `playground-*`.  