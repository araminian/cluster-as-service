set shell := ["bash", "-euo", "pipefail", "-c"]
set export
set positional-arguments

#DIRS
SKAFFOLDS_DIR := "skaffolds"
CLUSTERS_DIR := "clusters"

#VARS
GIT_USER := `git config --get user.name`
INGRESS := "ingress.cloudarmin.me"

apply:
  #!/usr/bin/env bash
  set -euo pipefail
  USER_CLUSTER_DIR="${CLUSTERS_DIR}/${GIT_USER}"

  if [ -d "$USER_CLUSTER_DIR" ]; then
    echo "The user '$GIT_USER' cluster directory exists."
    echo "Can't create a new cluster!"
    exit 1
  fi
  echo "Creating a new cluster for user: '$GIT_USER'..."
  
  mkdir -p "$USER_CLUSTER_DIR" && touch $USER_CLUSTER_DIR/.gitkeep
  
  mkdir -p "$USER_CLUSTER_DIR/vcluster"
  skaffold render --namespace $GIT_USER -f "$SKAFFOLDS_DIR/vcluster.yaml" -o "$USER_CLUSTER_DIR/vcluster/cluster.yaml"
  
  mkdir -p "$USER_CLUSTER_DIR/bootstrap"
  skaffold render --namespace $GIT_USER -f "$SKAFFOLDS_DIR/bootstrap.yaml" -o "$USER_CLUSTER_DIR/bootstrap/bootstrap.yaml"


argoapp ARGO_APP_NAME REPO_URL REPO_PATH CLUSTER_NAME PROJECT_NAME OUTPUT:
  #!/usr/bin/env bash
  skaffold render -f "$SKAFFOLDS_DIR/argoapp.yaml" -o "$OUTPUT"

destroy:
  #!/usr/bin/env bash
  set -euo pipefail
  USER_CLUSTER_DIR="${CLUSTERS_DIR}/${GIT_USER}"
  if [ ! -d "$USER_CLUSTER_DIR" ]; then
    echo "The user '$GIT_USER' cluster directory does not exist."
    echo "Can't destroy a cluster!"
    exit 1
  fi
  echo "Destroying cluster for user: '$GIT_USER'..."
  rm -rf "$USER_CLUSTER_DIR"
