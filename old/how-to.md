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

## How to inspect what is going in the flux pod

Connect to the flux container,

```sh
kubectl exec flux-7884c64d85-ktmnq -it -c flux /bin/bash
```

Every time flux clone the repo it will create a new dir under `/tmp/`  
You will have to look at the timestamp to figure out which is the latest clone, which is the one flux currently operates on

Example output:

```sh
bash-4.4# ls -la /tmp/
total 40
drwxrwxrwt    1 root     root          4096 Sep 12 12:19 .
drwxr-xr-x    1 root     root          4096 Sep 12 08:50 ..
drwx------    7 root     root          4096 Sep 12 08:50 flux-gitclone585494453
drwx------    7 root     root          4096 Sep 12 11:21 flux-working179481365
drwx------    7 root     root          4096 Sep 12 11:49 flux-working236445644
drwx------    7 root     root          4096 Sep 12 11:29 flux-working356751641
drwx------    7 root     root          4096 Sep 12 11:17 flux-working405851015
drwx------    7 root     root          4096 Sep 12 11:19 flux-working566546257
drwx------    7 root     root          4096 Sep 12 08:50 flux-working590250415
drwx------    7 root     root          4096 Sep 12 11:58 flux-working608275369
```
