## Repository structure

The Git repository contains the following top directories:

- **apps** dir contains Helm releases with a custom configuration per cluster
- **infrastructure** dir contains common infra tools such as NGINX ingress controller and Helm repository definitions
- **clusters** dir contains the Flux configuration per cluster

```
├── apps
│   ├── base
│   ├── production 
│   └── staging
├── infrastructure
│   ├── nginx
│   ├── redis
│   └── sources
└── clusters
    ├── production
    └── staging
```