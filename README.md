# Clustr as a Service
Here's my implementation of Cluster as a Service, leveraging vCluster as the primary tool for provisioning Virtual Clusters.

I explain the architecture and the implementation in detail in this [blog post]().

## How to use this solution for yourself

1. Provision a Kubernetes cluster as Host Cluster
2. Fork this repository, We call this repository as `CAAS_REPO` and remove any directory in the `clusters` directory.
```bash
# Remove any directory in the clusters directory
find clusters -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \; 
```
3. Install following tools on Cluster:
    - [ArgoCD](https://argo-cd.readthedocs.io/en/stable/getting_started/)
    - [Kyverno](https://kyverno.io/docs/installation/)
    - [Istio](https://istio.io/latest/docs/setup/getting-started/)
4. Users that need to provision Virtual Clusters need to have following tools installed:
    - [vCluster](https://www.vcluster.com/docs/getting-started/setup)
    - [Justfile](https://github.com/casey/just)
5. Configure an Ingress Gateway for Istio. We need a `INGRESS_URL` for this.
    - Create a `Certificate` for `*.INGRESS_URL`. I recommend to use [cert-manager](https://cert-manager.io/docs/installation/kubernetes/) for this.
    - Create a `Gateway` for `*.INGRESS_URL` and point it to the `istio-ingressgateway` service.
    ```yaml
    apiVersion: networking.istio.io/v1beta1
    kind: Gateway
    metadata:
    name: internal
    namespace: istio-system
    spec:
    selector:
        istio: ingressgateway
    servers:
    - hosts:
        - '*.[INGRESS_URL]' # replace [INGRESS_URL] with your ingress url
        port:
        name: http
        number: 80
        protocol: HTTP
    - hosts:
        - '*'
        port:
        name: https
        number: 443
        protocol: HTTPS
        tls:
        credentialName: istio-ingress-cert # Use the certificate created in the previous step
        mode: SIMPLE
    ```
6. Create an `ArgoCD Application` to deploy manifests to `Host Cluster` and `Virtual Clusters`.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    path: argo-apps
    repoURL: [CAAS_REPO] # replace [CAAS_REPO] with your forked repository
    targetRevision: HEAD
    directory:
      include: '{*.yaml,*.yml}'
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: true
```
7. Replace the `INGRESS_URL` and `CAAS_REPO` in the `justfile`:
```makefile
INGRESS := env_var_or_default('CLUSTER_INGRESS',"[INGRESS_URL]") # replace [INGRESS_URL] with your ingress url
REPO_URL := env_var_or_default('GITOPS_REPO',"[CAAS_REPO]") # replace [CAAS_REPO] with your forked repository
```

Now you are ready to provision Virtual Clusters. You can use the `just` targets to provision Virtual Clusters.

## How to specify tools to be installed on Virtual Cluster
This step is optional for users. By default, all tools in the `features.default` file will be installed on Virtual Cluster. But users can specify which tools they want to install on Virtual Cluster by running following `target`:

```bash
just configure
```

This command prompts users to select which tools they'd like to install on the Virtual Cluster. Their choices will be saved in the `features` file. When provisioning the Virtual Cluster, the `features` file will be read, and the specified tools will be installed accordingly.



## How to provision a Virtual Cluster
First we request for a Virtual Cluster by running following target:
```bash
just apply
```

Running this command will generate all the necessary manifests. Manifests will be committed to a branch, after which a pull request needs to be created to merge them.

By default, the cluster name is set as `Git Username``, but we can adjust it by setting the `CLUSTER_NAME` environment variable:
```bash
CLUSTER_NAME=demo just apply
```

Next, let's connect to the Virtual Cluster and get `kubeconfig`:

```bash
just kubeconfig
```
or following command in case of use different name for Virtual Cluster:
```bash
CLUSTER_NAME=demo just kubeconfig
```

then we need to set `kubeconfig` path:

```bash
export KUBECONFIG=./kubeconfig-[CLUSTER_NAME].yaml
```

There are some example applications in the `example` directory that can be deployed to the Virtual Cluster.

Finally we can destroy Virtual Cluster by running following command. The manifests are removed from the repository and committed to a branch. Initiating a pull request and merging it to the main branch will trigger the destruction of Virtual Clusters.

```bash
just destroy
```

or following command in case of use different name for Virtual Cluster:

```bash
CLUSTER_NAME=demo just destroy
```

## How to add more tools as option to be installed on Virtual Cluster
We have the option to include additional tools for users to install on the Virtual Cluster. For instance, I've already included `Knative` as an example.

There are two steps to add more tools:

1. Create a `Skaffold` file for the tool in the `skaffolds` direcotry with name of desired tool. For example, I created `knative.yaml` for `Knative`.

2. Add the tool to the `features` list in the `justfile` in the `configure` target:
```makefile
  features=(
    "istio"
    "knative"
  )
```

We can set a tool as the default in case a user doesn't specify any. This involves adding the tool to the `features.default` file:

```text
istio
knative
```

