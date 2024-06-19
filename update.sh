#!/bin/bash

function validate_step {
  local pid=$!
  local success_message=$1
  local failure_message=$2
  local validation_command=$3

  wait $pid
    local exit_code=$?
    echo "Exit code: $exit_code"
    if [ $exit_code -eq 0 ]; then
         if eval $validation_command; then
      echo "$success_message"
      else
          echo "$failure_message"
      return 1
    fi
    else
      echo "$failure_message"
      return 1
    fi
    return 0
}


function check_pods() {
  kubectl get pods --all-namespaces --field-selector=spec.nodeName=$1 -o json | \
  jq '[.items[] | select(.metadata.ownerReferences[].kind != "DaemonSet" and .spec.schedulerName != "static-scheduler")] | length'
}

function confirm_proceed {
  local next_step=$1
  echo "Do you want to proceed to the next step ($next_step)? (y/n)"
  read proceed_choice
  if [ "$proceed_choice" != "y" ]; then
    echo "Exiting..."
    exit 0
  fi
}

function cordon_node {
  echo "Cordoning node $1..."
  (kubectl cordon $1) &
  validate_step \
    "Node $1 cordoned successfully." \
    "Failed to cordon node $1." \
    "kubectl get nodes $1 -o jsonpath='{.spec.unschedulable}' | grep -q true"
}

function drain_node {
  echo "Draining node $1..."
  kubectl drain $1 --ignore-daemonsets --delete-emptydir-data --force 
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Failed to drain node $1."
    return 1
  fi

  # Continuously check if the node is cleared of non-daemonset and non-static pods
  while true; do
    local pod_count=$(check_pods $1)
    echo "Remaining pods: $pod_count"
    echo "tandz: $pod_count"
    echo "xndzor: $1"

    if [ "$pod_count" -eq 0 ]; then
      echo "Node $1 drained successfully."
      break
    else
      echo "Waiting for all pods to terminate. Checking again in 3 seconds..."
      sleep 3
    fi
  done
}
# function upgrade_node {
#   echo "Upgrading kubelet and kubectl..."
#   (sudo apt-mark unhold kubelet kubectl && \
#    sudo apt-get update && \
#    sudo apt-get install -y kubelet='1.30.x-*' kubectl='1.30.x-*' && \
#    sudo apt-mark hold kubelet kubectl && \
#    sudo systemctl daemon-reload && \
#    sudo systemctl restart kubelet) &
#   validate_step \
#     "Kubelet and kubectl upgraded successfully." \
#     "Failed to upgrade kubelet and kubectl." \
#     "kubelet --version && kubectl version --client"
# }


function upgrade_node {
  echo "Upgrading Minikube..."
  (curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && sudo install minikube-linux-amd64 /usr/local/bin/minikube) &
  validate_step \
    "Minikube upgraded successfully." \
    "Failed to upgrade Minikube." \
    "minikube version | grep -q $(curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | jq -r .tag_name)"
}

function uncordon_node {
  echo "Uncordoning node $1..."
  (kubectl uncordon $1) &
  validate_step \
    "Node $1 uncordoned successfully." \
    "Failed to uncordon node $1." \
    "[ \"\$(kubectl get node $1 -o jsonpath='{.spec.unschedulable}')\" != 'true' ]"
}

function full_update {
  echo "Enter the node name:"
  read node_name
  if cordon_node $node_name; then
    confirm_proceed "Drain Node"
    if drain_node $node_name; then
      confirm_proceed "Upgrade Node"
      if upgrade_node; then
        confirm_proceed "Uncordon Node"
        uncordon_node $node_name
      fi
    fi
  fi
}

function from_preferred_step {
  echo "Enter the node name:"
  read node_name
  echo "Select the step to start from:"
  echo "1. Cordon Node"
  echo "2. Drain Node"
  echo "3. Upgrade Node"
  echo "4. Uncordon Node"
  read step_choice
  case $step_choice in
    1)
      if cordon_node $node_name; then
        confirm_proceed "Drain Node"
        if drain_node $node_name; then
          confirm_proceed "Upgrade Node"
          if upgrade_node; then
            confirm_proceed "Uncordon Node"
            uncordon_node $node_name
          fi
        fi
      fi
      ;;
    2)
      if drain_node $node_name; then
        confirm_proceed "Upgrade Node"
        if upgrade_node; then
          confirm_proceed "Uncordon Node"
          uncordon_node $node_name
        fi
      fi
      ;;
    3)
      if upgrade_node; then
        confirm_proceed "Uncordon Node"
        uncordon_node $node_name
      fi
      ;;
    4)
      uncordon_node $node_name
      ;;
    *)
      echo "Invalid selection, please try again."
      ;;
  esac
}

function display_main_menu {
  echo "Select an action:"
  echo "1. Full Update"
  echo "2. Start from Preferred Step"
  echo "3. Exit"
}

while true; do
  display_main_menu
  echo "Enter your choice:"
  read main_choice
  case $main_choice in
    1)
      full_update
      ;;
    2)
      from_preferred_step
      ;;
    3)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid selection, please try again."
      ;;
  esac
done
