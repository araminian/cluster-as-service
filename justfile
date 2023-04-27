set shell := ["bash", "-euo", "pipefail", "-c"]
set export
set positional-arguments

#DIRS
BOOTSTRAP_DIR := "bootstrap"
CLUSTERS_DIR := "clusters"

#VARS
GIT_USER := `git config --get user.name`

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
  
  skaffold render -f "$BOOTSTRAP_DIR/skaffold.yaml" -o "$USER_CLUSTER_DIR/cluster.yaml"
