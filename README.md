## Repository structure

The Git repository contains the following top directories:

- **clusters** directory contains the Flux configuration per cluster.
- **components** directory contains all components deployed to the cluster with base configuration.

```
├── clusters
│   │
│   ├── c2-production
│   │   ├── (flux-system)
│   │   ├── infrastructure
│   │   │   ├── radix-platform
│   │   │   └── third-party
│   │   ├── flux-patches.yaml
│   │   ├── healthChecks.yaml
│   │   └── kustomization.yaml
│   │
│   ├── development
│   │   ├── (flux-system)
│   │   ├── infrastructure
│   │   │   ├── radix-platform
│   │   │   └── third-party
│   │   ├── flux-patches.yaml
│   │   ├── healthChecks.yaml
│   │   └── kustomization.yaml
│   │
│   ├── monitoring
│   │   ├── (flux-system)
│   │   ├── infrastructure
│   │   │   ├── radix-platform
│   │   │   └── third-party
│   │   ├── flux-patches.yaml
│   │   └── kustomization.yaml
│   │
│   ├── playground
│   │   ├── (flux-system)
│   │   ├── infrastructure
│   │   │   ├── radix-platform
│   │   │   └── third-party
│   │   ├── flux-patches.yaml
│   │   ├── healthChecks.yaml
│   │   └── kustomization.yaml
│   │
│   └── production
│       ├── (flux-system)
│       ├── infrastructure
│       │   ├── radix-platform
│       │   └── third-party
│       ├── flux-patches.yaml
│       ├── healthChecks.yaml
│       └── kustomization.yaml
│
└── components
    ├── flux
    ├── third-party
    └── radix-platform
```

# Clusters

## Flux system

The `flux-system` directory underneath parent folder `clusters` is created and managed by Flux.

## Infrastructure

Each cluster contains an `infrastructure` directory with two sub-directories: `radix-platform` and `third-party`. Each file in these directories is a Flux `Kustomization` manifest that deploys the corresponding component from the `components` directory. The cluster-specific configuration — such as patches and substitute variables — is defined directly in each Kustomization manifest.

The cluster's `kustomization.yaml` imports these directories:

```yaml
# file: clusters/development/kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - flux-system
  - ./infrastructure/third-party
  - ./infrastructure/radix-platform
  - ../../components/flux/storageclasses
patches:
  - path: ./flux-patches.yaml
```

Each Kustomization in the `infrastructure` directory points to a path in `components` and includes its own `patches` and `substitute` variables. For example, `radix-operator` defines cluster-specific helm values and image versions directly:

```yaml
# file: clusters/development/infrastructure/radix-platform/radix-operator.yaml

apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: radix-operator
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./components/radix-platform/radix-operator
  prune: false
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: radix-flux-config
    substitute:
      RADIX_OPERATOR_CHART_VERSION: 1.119.0 # {"$imagepolicy": "flux-system:radix-operator-chart:tag"}
  patches:
    - patch: |-
        apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        metadata:
          name: radix-operator
          namespace: default
        spec:
          values:
            rbac:
              createApp:
                groups:
                  - ec8c30af-ffb6-4928-9c5c-4abf6ae6f82e # Radix
      target:
        kind: HelmRelease
        name: radix-operator
        namespace: default
```

## Flux patches

The `flux-patches.yaml` file in each cluster directory patches the Flux controller `Deployment` resources directly. This is used to configure cluster-specific settings such as node affinity for the Flux controllers.

## Health checks

The `healthChecks.yaml` file patches the `flux-system` Kustomization to define health checks for the cluster:

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

apiVersion: image.toolkit.fluxcd.io/v1beta2
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

The imagePolicy resource specifies how Flux will identify the latest container image scanned from the imageRepository. The `policy` spec specifies whether the latest image is found by a SemVer range or by alphabetical or numerical sorting. If the image tag contains a timestamp, the timestamp can be filtered and extracted using the `filterTags` spec.

```yaml
# file: components/radix-platform/radix-operator/imagePolicy.yaml

apiVersion: image.toolkit.fluxcd.io/v1beta2
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

apiVersion: image.toolkit.fluxcd.io/v1beta2
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

Flux identifies the values to change by looking for an "image policy marker" which contains the name and namespace of the imagePolicy. The marker also specifies whether it is the image name or the tag which is the value.

- `{"$imagepolicy": "namespace:radix-operator"}` resolves to `radixdev.azurecr.io/radix-operator:master-a5e880b9-1634484632`
- `{"$imagepolicy": "namespace:radix-operator:name"}` resolves to `radixdev.azurecr.io/radix-operator`
- `{"$imagepolicy": "namespace:radix-operator:tag"}` resolves to `master-a5e880b9-1634484632`

Image policy markers are placed inline in the Kustomization manifests under `clusters/<cluster>/infrastructure/`:

```yaml
# file: clusters/development/infrastructure/radix-platform/radix-operator.yaml

    substitute:
      RADIX_OPERATOR_CHART_VERSION: 1.119.0 # {"$imagepolicy": "flux-system:radix-operator-chart:tag"}
```

## kustomization.yaml

In each of the cluster environment directories and component sub-directories, there is a `kustomization.yaml` file which specifies which resources should be deployed.

# Components

All components are defined in the `components` directory with base configuration that is common for all cluster environments, such as the Helm repository, namespace, and shared Helm release values. Each cluster's Kustomization manifest in `infrastructure/` points to the relevant path in `components/` and adds its own cluster-specific patches and substitute variables on top.

In each component directory there is also a `kustomization.yaml` file which defines the resources in that directory which are to be deployed. This enables specifying only the path to the directory in a Flux Kustomization manifest, rather than specifying each file in the directory separately. The `kustomization.yaml` file acts like an index.

Want to contribute? Read our [contributing guidelines](./CONTRIBUTING.md)  

---------

[Security notification](./SECURITY.md)
