# radix-flux for DEVELOPMENT environments

For general info like file structure, naming conventions, usage etc please see [readme](https://github.com/equinor/radix-flux) in master branch.  


## Dependencies on radix platform configuration and secrets

In order to ease installation and use of radix components, and to not have to repeat the same values for every installation, we have moved some of the shared information and credentials out of the radix-operator chart.

- ConfigMap: `radix-platform-config`
- Secret: `radix-docker` 
- Secret: `radix-sp-acr-azure`  

All are created by the [install_base_components.sh](https://github.com/equinor/radix-platform/blob/master/scripts/install_base_components.sh) script.


## Transition of ye olde version of radix-operator to fluxed flash of hotness

- The radix-operator helm chart is now synced to and run from the flux repo
- The creation of secrets have been refactored out

### Install flux in a "old" cluster

TLDR: run installation of base components twice.  

When installing flux into a cluster that has a radix-operator installed then flux will take control of that chart.  
A side effect of this is that the secrets the old chart controlled will be deleted.  
To recreate these secrets then simply run the installation of base components again.