# Radix-Flux

Radix k8s GitOps using Weavework Flux.

_Radix flux docs:_
- [How to flux](./how-to.md)
- [Flux manifest factorization](./flux-manifest-factorization.md)
- [Known issues](./known-issues.md)
- [Radix platform components](https://github.com/equinor/radix-private/blob/master/docs/radix-platform/readme.md)

_Official docs:_
- [Weavework Flux](https://github.com/fluxcd/flux)
- [Weavework Flux - Helm operator](https://github.com/fluxcd/flux#get-started-with-the-helm-operator)
- [Weavework Flux - HelmRelease Custom Resource](https://docs.fluxcd.io/en/latest/helm-operator/references/helmrelease-custom-resource.html)


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

### Flux manifest factorization

See [flux-manifest-factorization.md](./flux-manifest-factorization.md) for a high level introduction.

## How we use it

### Shared cluster configs per cluster environment

We do not store configs for a single cluster.  
Example: we have multiple development cluster, and they all share the same configs found in directory `./development-configs/`

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

### Flux manifest factorization in radix

#### Deploy configs

Some of our manifests rely on metadata that has been preinstalled in the cluster (configmap `radix-platform-config`).  
We can inject these values into the manifests by:

1. Use shell variables in manifests, making them into templates. These templates are stored in the config repo.
1. Tell flux (see `.flux.yaml` in each config dir, and look at the `generator` commands) that it should use a shell script to transform specified manifest templates into manifests
   1. The shell script `update_radix_patch.sh` will use `kubectl` to read the values from the cluster, transform the templates and add the result to a temporary file called `radix-patch.yaml`
1. The final step is to instruct flux to use `kustomize` to combine all the manifests, including the `radix-patch.yaml` as a k8s patch (see `kustomize.yaml` in each config dir)
1. The output from `kustomize` is what flux will then deploy to the cluster (implicit behaviour)
   1. If `.flux.yaml` is set to use `patchUpdated` configuration then it will also deploy `flux-patch.yaml` if found (implicit behaviour).  
      For details on `patchUpdated` then see "Update configs" down below

_Note:_  
The `radix-patch.yaml` is a temporary file that contains cluster specific data, and it should not be pushed back to the repo. We can tell flux to ignore it by adding it to `.gitignore`. The file will not be reused in later workloads as flux will create a separate workload dir for each update cycle.

#### Update configs

We want flux to update some manifests when new images appear in the container registry (example: see image filter in `{environment}-configs/radix-platform/radix-operator.yaml`).  
When we use flux manifest factorization then we also need to specify how flux should update the manifest. This can be quite hard to implement correctly, and so flux provide a way to store all updates triggered by Flux in a separate file called `flux-patch.yaml`. This feature is enabled by using [patchUpdated configuration](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md#using-annotations-to-control-updates-to-helmrelease-resources) in the `.flux.yaml`.

The update configs workflow goes like this:

1. Flux discover a new image in the container registry
1. Flux discover an image filter in one of the manifests it tracks
1. Flux will update the manifest image in the file `flux-patch.yaml`
1. Flux will finally commit and push to the config repo

This will trigger a new "Deploy configs" cycle where flux will deploy the patch.



## Development flow

### Step 1: Implement and test configuraton in a separate cluster

_Setup dev environment_  
1. Create a task branch from branch `master`, ie "RA-999-adding-some-component...", in config repo  
   ```sh
   # Be sure that you got the latest changes (ie pull request) in local repo
   git checkout master
   git pull
   git checkout -b "RA-999-adding some component to Development"
   ```
1. Add the config changes to the branch in directory `/development-configs/`
1. Bootstrap a new radix cluster
1. When you install the base components then point flux to your task branch and directory (see base components script for how)
1. View the flux container log to see that it can find your configs
   1. If flux is having trouble, ie wrong config path, then simply redeploy flux (there is a standalone script for this, or run base components script again) to your cluster with correct settings
1. When you see that flux can find your configs and you see the deployments roll out then this setup is complete

_Iterate_
1. Push changes to your branch
1. Either wait for flux sync or make it sync now by executing command `fluxctl sync`  
   NB! Syncing flux != execute changes now. It will simply make flux add a new workload to it's internal queue, meaning it will take a couple of minutes before it executes your changes.
1. Watch for changes in the cluster
1. Repeat

### Step 2: Review and deploy to development cluster(s)

1. Run pull request for merging your task branch to branch `master`
1. Inspect development cluster(s) to see that the changes in `master` are deployed as expected

By deploying your changes to `development` cluster in one big go like this is that you can now verify that other radix clusters than your dev cluster can handle the update.  
This is as close as we can get to the same behaviour as when deploying to `production` and `playground`.

### Step 3: Implement and deploy to Production and Playground

1. Create a task branch from `master`, ie "RA-999-adding some component to Prod and Playground", in config repo  
   ```sh
   # Be sure that you got the latest changes (ie pull request) in local repo
   git checkout master
   git pull
   git checkout -b "RA-999-adding some component to Prod and Playground"
   ```
1. Add/update configs for `production` and `playground` in corrensponding directories
1. Run pull request to merge to branch `master`
1. Finally release changes to `production` and `playground` by merging branch `master` into `release`  
   ```sh
   # Be sure that master has latest changes
   git checkout master
   git pull
   # Be sure that release has latest changes
   git checkout release
   git pull
   # Finally merge master into release
   git merge master
   git push
   ```
1. Inspect cluster `production` and `playground` to verify deployment

