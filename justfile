set shell := ["bash", "-euo", "pipefail", "-c"]
set export
set positional-arguments

#DIRS
SKAFFOLDS_DIR := "skaffolds"
CLUSTERS_DIR := "clusters"

#VARS
GIT_USER := `git config --get user.name`
INGRESS := "ingress.cloudarmin.me"
REPO_URL := "https://github.com/araminian/cluster-as-service.git"


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
  
  mkdir -p "$USER_CLUSTER_DIR/vcluster"
  skaffold render --namespace $GIT_USER -f "$SKAFFOLDS_DIR/vcluster.yaml" -o "$USER_CLUSTER_DIR/vcluster/cluster.yaml"
  
  mkdir -p "$USER_CLUSTER_DIR/bootstrap"
  skaffold render --namespace $GIT_USER -f "$SKAFFOLDS_DIR/bootstrap.yaml" -o "$USER_CLUSTER_DIR/bootstrap/bootstrap.yaml"

  just argoapp "${GIT_USER}-vcluster" "$REPO_URL" "$USER_CLUSTER_DIR" "in-cluster" "default" "argo-apps/${GIT_USER}-vcluster.yaml"

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
  echo "Committing changes..."
  git add .
  git commit -m "Delete cluster for user: '$GIT_USER'"
  git push --set-upstream origin "$BRANCH_NAME"
  echo "Please create a PR to merge '$BRANCH_NAME' into 'main' branch."
  echo "After merging the PR, the cluster will be destroyed."
  echo "Back to main branch..."
  git checkout main


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
 