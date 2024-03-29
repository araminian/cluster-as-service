set shell := ["bash", "-euo", "pipefail", "-c"]
set export
set positional-arguments

#DIRS
SKAFFOLDS_DIR := "skaffolds"
CLUSTERS_DIR := "clusters"

#VARS
REAL_GIT_USER := `git config --get user.name`
GIT_USER := env_var_or_default('CLUSTER_NAME',REAL_GIT_USER)
INGRESS := env_var_or_default('CLUSTER_INGRESS',"ingress.cloudarmin.me")
REPO_URL := env_var_or_default('GITOPS_REPO',"https://github.com/araminian/cluster-as-service.git")

default:
  just --list

# Create a cluster for a user
apply:
  #!/usr/bin/env bash
  set -eu pipefail
  USER_CLUSTER_DIR="${CLUSTERS_DIR}/${GIT_USER}"

  git checkout main && git pull
  
  if [ -d "$USER_CLUSTER_DIR" ]; then
    echo "The user '$GIT_USER' cluster directory exists."
    echo "Can't create a new cluster!"
    exit 1
  fi
  echo "Creating a new cluster for user: '$GIT_USER'..."
  
  BRANCH_NAME="create-vcluster-${GIT_USER}-$(echo $RANDOM | md5sum | head -c 10; echo;)"

  echo "Create a new branch: '$BRANCH_NAME'..."
  git checkout -b "$BRANCH_NAME"

  mkdir -p "$USER_CLUSTER_DIR" && touch $USER_CLUSTER_DIR/.gitkeep
  
  mkdir -p "$USER_CLUSTER_DIR/cluster/vcluster"
  skaffold render --namespace $GIT_USER -f "$SKAFFOLDS_DIR/vcluster.yaml" -o "$USER_CLUSTER_DIR/cluster/vcluster/cluster.yaml"
  
  mkdir -p "$USER_CLUSTER_DIR/cluster/bootstrap"
  skaffold render --namespace $GIT_USER -f "$SKAFFOLDS_DIR/bootstrap.yaml" -o "$USER_CLUSTER_DIR/cluster/bootstrap/bootstrap.yaml"

  just argoapp "${GIT_USER}-vcluster" "$REPO_URL" "$USER_CLUSTER_DIR/cluster" "in-cluster" "default" "argo-apps/${GIT_USER}-vcluster.yaml"

  mkdir -p "$USER_CLUSTER_DIR/tools"
  just argoapp "${GIT_USER}-vcluster-tools" "$REPO_URL" "$USER_CLUSTER_DIR/tools" "$GIT_USER" "default" "argo-apps/${GIT_USER}-vcluster-tools.yaml"

  echo "Checking features to be installed..."
  if [ ! -f features ]; then
    echo "Features file (features) does not exist."
    echo "Load default configurations..."
    cp features.default features
  fi
  

  while read -r feature; do
    echo "Rendering manifest for feature: '$feature'..."
    just render-feature "$feature" "$USER_CLUSTER_DIR/tools/$feature.yaml"
  done < features

  echo "Committing changes..."
  git add .
  git commit -m "Add cluster for user: '$GIT_USER'"
  git push --set-upstream origin "$BRANCH_NAME"
  echo "Please create a PR to merge '$BRANCH_NAME' into 'main' branch."
  echo "After merging the PR, the cluster will be created."
  echo "Back to main branch..."
  git checkout main

argoapp ARGO_APP_NAME REPO_URL REPO_PATH CLUSTER_NAME ARGO_PROJECT_NAME OUTPUT:
  #!/usr/bin/env bash
  set -eu pipefail
  skaffold render -f "$SKAFFOLDS_DIR/argoapp.yaml" -o "$OUTPUT"

# Destroy a cluster for a user
destroy:
  #!/usr/bin/env bash
  set -eu pipefail
  
  git checkout main && git pull

  USER_CLUSTER_DIR="${CLUSTERS_DIR}/${GIT_USER}"
  if [ ! -d "$USER_CLUSTER_DIR" ]; then
    echo "The user '$GIT_USER' cluster directory does not exist."
    echo "Can't destroy a cluster!"
    exit 1
  fi
  echo "Destroying cluster for user: '$GIT_USER'..."

  BRANCH_NAME="delete-vcluster-${GIT_USER}-$(echo $RANDOM | md5sum | head -c 10; echo;)"

  echo "Create a new branch: '$BRANCH_NAME'..."
  git checkout -b "$BRANCH_NAME"
  
  rm -rf "$USER_CLUSTER_DIR"
  rm -rf "argo-apps/${GIT_USER}-vcluster.yaml"
  rm -rf "argo-apps/${GIT_USER}-vcluster-tools.yaml"
  echo "Committing changes..."
  git add .
  git commit -m "Delete cluster for user: '$GIT_USER'"
  git push --set-upstream origin "$BRANCH_NAME"
  echo "Please create a PR to merge '$BRANCH_NAME' into 'main' branch."
  echo "After merging the PR, the cluster will be destroyed."
  echo "Back to main branch..."
  git checkout main


# Get kubeconfig for a user
kubeconfig:
  #!/usr/bin/env bash
  set -eu pipefail
  if kubectl get namespace $GIT_USER > /dev/null 2>&1; then
    echo "Vcluster '$GIT_USER' exists"
    vcluster connect $GIT_USER -n $GIT_USER --update-current=false --server=https://cluster-${GIT_USER}.${INGRESS} --kube-config ./kubeconfig-${GIT_USER}.yaml
  else
    echo "Vcluster '$GIT_USER' does not exist"
    exit 1
  fi
 
# Configure features
configure:
  #!/usr/bin/env bash
  set -eu pipefail
  echo "Creating configration file (features)..."
  rm -rf features
  touch features
  
  features=(
    "istio"
    "knative"
  )
  for feature in "${features[@]}"; do
    just enable-feature "$feature"
  done

enable-feature NAME:
  #!/usr/bin/env bash
  set -eu pipefail
  echo "Do you need '$NAME' in your cluster?(y/n)"
  read -r feature
  if [ "$feature" == "y" ]; then
    echo "$NAME" >> features
  fi

render-feature NAME OUTPUT:
  #!/usr/bin/env bash
  set -eu pipefail
  skaffold render --offline=true -f "$SKAFFOLDS_DIR/${NAME}.yaml" -o $OUTPUT

_test:
  #!/usr/bin/env bash
  set -eux pipefail
  cp features.default features
  while read -r line; do
    echo "$line"
  done < features