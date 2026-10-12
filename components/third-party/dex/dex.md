# Dex IdP (development cluster)

Dex runs at `https://simpleauth.dev.radix.equinor.com` in the `radix-easyauth` namespace. It forwards all logins to Azure AD (Radix SimpleAuth app registration, client ID `62477cbd-ddbe-4903-9d60-a071209277a1`) and issues tokens to its own registered clients.

## What has been done

- Component [components/third-party/dex/](components/third-party/dex/):
  - `namespace.yaml`: creates the `radix-easyauth` namespace.
  - `ociRepo.yaml`, `imageRepo.yaml`, `imagePolicy.yaml`: chart source `oci://ghcr.io/dexidp/helm-charts/dex`. The chart version is updated automatically by Flux image automation.
  - `secretStore.yaml`: a `workload-identity-sa` ServiceAccount and a `radix-keyvault` SecretStore in the `radix-easyauth` namespace, using the External Secrets managed identity (`b3f4e788-84bd-458e-9f49-d62f1c325a8d`).
  - `externalSecret.yaml`: syncs Key Vault secret `dex-azure-client-secret` into the Kubernetes secret `radix-easyauth/dex-secrets` (key `DEX_AZURE_CLIENT_SECRET`).
  - `helmRelease.yaml` configures Dex as follows:
    - The issuer is `https://simpleauth.${dnsZone}`, served by an HTTPRoute on the `istio-system/gateway` `https` listener. The existing `*.dev.radix.equinor.com` wildcard certificate covers it.
    - Login state is stored in Kubernetes CRDs.
    - Logins go through the `microsoft` connector to the Equinor tenant using a client secret.
    - Static client `rihag.dev.radix.equinor.com` reads its secret from the manually created Kubernetes secret `radix-easyauth/dex-client-rihag`.
    - Containers run locked down: non-root, read-only filesystem, all capabilities dropped.
- Flux Kustomization [clusters/development/infrastructure/third-party/dex.yaml](clusters/development/infrastructure/third-party/dex.yaml), registered in `kustomization.yaml` there.
- Client app PRs: https://github.com/Equinor-Playground/rihag/pull/2 points the `web` component's OAuth2 proxy in the `dev` environment to Dex, and a follow-up PR switches it to the `simpleauth` issuer.

### Why client secrets instead of workload identity

- **Dex to Azure AD:** the `microsoft` connector's `clientAssertion` (workload identity) is only on Dex `master`. It is not in the latest release, `v2.45.1`. When it is released, switch to it and remove `dex-azure-client-secret`.
- **Clients to Dex:** Dex only supports client ID and secret authentication for its clients.

## Manual steps

### 1. Federated credential for External Secrets

The SecretStore in the `radix-easyauth` namespace uses ServiceAccount `radix-easyauth/workload-identity-sa` with the External Secrets managed identity. In the Azure portal, add a federated credential on that managed identity (client ID `b3f4e788-84bd-458e-9f49-d62f1c325a8d`):

| Field           | Value                                                                                                            |
| --------------- | ---------------------------------------------------------------------------------------------------------------- |
| Scenario        | Kubernetes accessing Azure resources                                                                             |
| Issuer          | Cluster OIDC issuer: `kubectl get cm -n flux-system radix-flux-config -o jsonpath='{.data.kubernetesIssuerUrl}'` |
| Namespace       | `radix-easyauth`                                                                                                 |
| Service account | `workload-identity-sa`                                                                                           |
| Audience        | `api://AzureADTokenExchange`                                                                                     |

Repeat this for every development cluster issuer, because a new cluster gets a new issuer URL.

### 2. Azure AD app registration (SimpleAuth, `62477cbd-…`)

- Add the Web redirect URI `https://simpleauth.dev.radix.equinor.com/callback`.
- Create a client secret and store it in Key Vault `radix-keyv-dev` as `dex-azure-client-secret`.

### 3. rihag client secret (native Kubernetes secret)

Generate a random value and create the secret in the cluster. Flux does not manage this secret.

```sh
kubectl create secret generic dex-client-rihag -n radix-easyauth \
  --from-literal=clientSecret="$(openssl rand -base64 32)"
```

Set the same value as the OAuth2 client secret for the `web` component in the `dev` environment of `rihag` in Radix Web Console:

```sh
kubectl get secret -n radix-easyauth dex-client-rihag -o jsonpath='{.data.clientSecret}' | base64 -d
```

If the secret changes, restart Dex: `kubectl rollout restart deploy/dex -n radix-easyauth`.

## Verify

```sh
flux get kustomization dex
kubectl get externalsecret,secret -n radix-easyauth
kubectl get pods,httproute -n radix-easyauth
curl -s https://simpleauth.dev.radix.equinor.com/.well-known/openid-configuration | jq .issuer
```

Then open `https://rihag.dev.radix.equinor.com`. It should redirect via Dex to Azure AD and back.

## Notes

- Only `https://rihag.dev.radix.equinor.com/oauth2/callback` is registered for the rihag client. To log in from other hostnames, add them to `staticClients[].redirectURIs` in `helmRelease.yaml`.
