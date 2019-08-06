# How to flux

## How to update manifest image

If the manifest use flux [image filter](https://github.com/weaveworks/flux/blob/master/site/fluxctl.md#using-annotations) then all you have to do is to simply build, tag and push your image to the container registry.  
Flux will then update the manifests in the config repo if it can match the manifest image filter to the new image tag, and then it will deploy the updated manifest.

Example:  
- Manifests in `development` clusters will have a flux image filter annotation that match `glob:master-*`
- Manifests in `production` clusters will have a flux image filter annotation that match `glob:release-*`  


## How to delete manifest in cluster while keeping it in the config repo

1. In config repo/branch, add the annotation `flux.weave.works/ignore: true` to the manifest you want Flux to ignore
1. In cluster, delete the manifest  


## How to delete manifest in cluster and config repo

1. In config repo/branch, delete the manifest
1. In cluster, delete the manifest  