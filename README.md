## Repository structure

The Git repository contains the following top directories:

- **clusters** directory contains the Flux configuration per cluster.
- **components** directory contains all components deployed to the cluster with base configuration.

```
├── clusters
│   │
│   ├── c2-production
│   │   ├── (flux-system)
│   │   ├── overlay
│   │   ├── healthChecks.yaml
│   │   ├── kustomization.yaml
│   │   └── postBuild.yaml
│   │
│   ├── development
│   │   ├── (flux-system)
│   │   ├── overlay
│   │   ├── healthChecks.yaml
│   │   ├── kustomization.yaml
│   │   └── postBuild.yaml
│   │
│   ├── monitoring
│   │   ├── (flux-system)
│   │   ├── overlay
│   │   └── kustomization.yaml
│   │
│   ├── playground 
│   │   ├── (flux-system)
│   │   ├── overlay
│   │   ├── healthChecks.yaml
│   │   ├── kustomization.yaml
│   │   └── postBuild.yaml
│   │
│   └── production
│       ├── (flux-system)
│       ├── overlay
│       ├── healthChecks.yaml
│       ├── kustomization.yaml
│       └── postBuild.yaml
│
└── components
    ├── flux
    ├── third-party
    └── radix-platform
```
# Clusters

## Flux system
The `flux-system` directory underneath parent folder `clusters` is created and managed by Flux. 
## Overlay
In Radix we want separate configurations per cluster. In order to achieve this we use Flux overlays which override the configuration defined in the `components` directory. The `overlay` directory has the same structure as the `components` directory, but contains only files for the resources to be overridden. The files then need to be included in the `kustomization.yaml` file in the cluster environment directory. 

For example, radix-operator uses cluster-specific configuration which requires overriding the helm release. The variable is substituted by Flux with the key found in `postBuild.yaml`.

```yaml
# file: clusters/development/overlay/radix-platform/radix-operator/radix-operator.yaml

apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: radix-operator
  namespace: flux-system
spec:
  patches:
    - patch: |-
        apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        metadata:
          name: radix-operator
          namespace: default
        spec:
          values:
            radixZone: ${RADIX_ZONE} # Set in postBuild development
```

```yaml
# file: clusters/development/postBuild.yaml

apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  postBuild:
    substitute:
      RADIX_ZONE: dev # dev | playground | prod
```

The radix-operator kustomization file needs to be included in the `kustomization.yaml` file.

```yaml
# file: clusters/development/kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1
kind: Kustomization
resources:
- ./overlay/radix-platform/radix-operator/radix-operator.yaml
```

We patch the `flux-system` Kustomization with cluster environment specific configuration. To make it clear which parts of the configuration is changed, we have separate files for separate fields. For example, we use `postBuild.yaml` to patch the `postBuild` spec of `flux-system` Kustomization, and `healthChecks.yaml` to patch the `healthChecks` spec. 

```yaml
# file: clusters/development/postBuild.yaml

apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  postBuild:
    substitute:
      RADIX_ZONE: dev # dev | playground | prod
      RADIX_ENVIRONMENT: dev # dev | prod
      radix_acr_repo_url: radixdev.azurecr.io
    substituteFrom:
      - kind: ConfigMap
        name: radix-flux-config
```

```yaml
# file: clusters/development/healthChecks.yaml

apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: velero
      namespace: velero
```

## Automatic image updates
Flux v2 can automatically track container registries for new pushed versions of container images and update the Flux configuration repository to upgrade the configured components, deployed to the cluster. To set up automatic image updates, three components are required. 

### ImageRepository
The ImageRepository defines the container registry where Flux should look for new versions of container images. If the container registry is private and requires authentication, a secret can be defined which contains credentials to access it. 

```yaml
# file: components/radix-platform/radix-operator/imageRepo.yaml

apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageRepository
metadata:
  name: radix-operator
  namespace: flux-system
spec:
  image: radixdev.azurecr.io/radix-operator
  interval: 1m0s
  secretRef:
    name: radix-docker
```
### imagePolicy
The imagePolicy resource specifies how Flux will identify the latest container image scanned from the imageRepository. The `policy` spec specifies whether the latest image is found by a SemVer range or by alphabetical or numberical sorting. If the image tag contains a timestamp, the timestamp can be filtered and extracted using the `filterTags` spec. 

```yaml
# file: components/radix-platform/radix-operator/imagePolicy.yaml

apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImagePolicy
metadata:
  name: radix-operator
  namespace: flux-system
spec:
  filterTags:
    pattern: ^master-[a-f0-9]+-(?P<ts>[0-9]+)
    extract: $ts
  imageRepositoryRef:
    name: radix-operator
  policy:
    numerical:
      order: asc
```

### imageUpdateAutomation
The imageUpdateAutomation resource specifies which Git repository and branch Flux should write image updates to. The Git repository should be the Flux configuration repository. It can be configured to commit directly to an existing branch, or to commit to a new branch. A GitHub workflow can be used to automatically create a Pull Request with the updated versions. The commit message can be customized to include information about the image updates. When Flux searches the imageRepository and finds a tag that is newer than the one in the Flux configuration repository, it will use the imageUpdateAutomation to commit the changes to a branch in the repository. 


```yaml
# file: components/flux/imageUpdateAutomation.yaml

apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: radix-dev-acr-auto-update
  namespace: flux-system
spec:
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    checkout:
      ref:
        branch: master
    commit:
      author:
        email: radix@statoilsrm.onmicrosoft.com
        name: FluxBot
      messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
    push:
      branch: flux-image-updates
  update:
    path: ${FLUX_CONFIG_PATH}
    strategy: Setters
```

The `path` spec specifies a directory with files, which is scanned regularly by Flux to find the values which should be changed. This prevents Flux from updating the overlay in all cluster environment configurations. The variable is defined in the `postBuild.yaml` file for the cluster. Flux identifies the values to change by looking for an "image policy marker" which contains the name and namespace of the imagePolicy. The marker also specifies whether it is the name or the tag which is the value. 

- `{"$imagepolicy": "namespace:radix-operator"}` resolves to `radixdev.azurecr.io/radix-operator:master-a5e880b9-1634484632`
- `{"$imagepolicy": "namespace:radix-operator:name"}` resolves to `radixdev.azurecr.io/radix-operator`
- `{"$imagepolicy": "namespace:radix-operator:tag"}` resolves to `master-a5e880b9-1634484632`

```yaml
# file: clusters/development/overlay/radix-platform/radix-operator/radix-operator.yaml

apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  postBuild:
    substitute:
      RADIX_OPERATOR_CHART_VERSION: 1.100.0 # {"$imagepolicy": "flux-system:radix-operator-chart:tag"}
```

## kustomization.yaml
In each of the cluster environment directories and component sub-directories, there is a `kustomization.yaml` file which specifies which resources should be deployed. 

# Components
All components are defined in the `components` directory with base configuration, which is the configuration that is common for all cluster environments such as the helm repository and namespace. The helm release of components are also defined here, but only with the values common for all cluster environments; the rest being set by the overlay. 

In each component directory there is also a `kustomization.yaml` file which defines the resources in that directory which are to be deployed. This enables specifying only the path to the directory in the `kustomization.yaml` file in the cluster environment directory, rather than specifying each file in the directory separately. The `kustomization.yaml` file acts like an index. 

Want to contribute? Read our [contributing guidelines](./CONTRIBUTING.md)  

---------

[Security notification](./SECURITY.md)
