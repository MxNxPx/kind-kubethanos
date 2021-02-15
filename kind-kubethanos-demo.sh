#!/bin/bash

. ./demo-magic.sh
echo;echo
PROMPT_TIMEOUT=0.1
MSG="LET'S GET THIS DEMO STARTED..."
COW="/usr/share/cowsay/cows/default.cow"
pei "echo \$MSG | cowsay -f \$COW"

## create kind cluster
echo;echo
PROMPT_TIMEOUT=0
p "[.] kind"
pei "kubectl cluster-info"
pei "docker ps"
pei "time (kind create cluster --config ./kind-config-1m2w-ingress.yaml --image kindest/node:v1.18.2 --wait 5m && kubectl wait --timeout=5m --for=condition=Ready nodes --all)"
pei "docker ps -a --format \"table {{.Names}}\\\t{{.Image}}\\\t{{.Status}}\""

## view cluster status
pe "kubectl get nodes -o wide"
pe "kubectl get pods -A"

## try to deploy old deployment spec
echo;echo
p "[.] k8s deployment and pod placement"
pe "kubectl create deployment nginx --image=nginx && kubectl scale deployment/nginx --replicas=5"

## verify working
pe "kubectl -n default get deploy,pods -o wide"

## lets test draining a node
p "[*] in another window:  watch 'kubectl get -n default deploy; echo; kubectl -n default get pods -o wide --sort-by=.status.startTime'"
pe "kubectl drain kind-worker --ignore-daemonsets"
pe "kubectl uncordon kind-worker"

echo;echo
p "[.] kubethanos"

## load the image into kind nodes
pe "kind load image-archive kubethanos.tar"
#or
#kind load docker-image docker.local/kubethanos:1.0

## scale up the innocent workload some more
pe "kubectl scale deployment/nginx --replicas=10"

## verify working
pe "kubectl -n default get deploy,pods -o wide"

## deploy the yaml spec
pe "sleep 30; kubectl apply -f kubethanos-infinitywar.yaml"

## snap!
p "[*] in another window:  watch 'kubectl get -n default deploy; echo; kubectl -n default get pods -o wide --sort-by=.status.startTime'"
p "[*] in another window:  kubectl -n kube-system logs deploy/thanoskube -f"

## what will happen this time?
pe "kubectl apply -f kubethanos-endgame.yaml"
p "[*] in another window:  kubectl -n kube-system logs deploy/thanoskube -f"

PROMPT_TIMEOUT=0
echo;echo
MSG="THE WORK IS DONE."
COW="./thanos.cow"
pe "echo \$MSG | cowsay -f \$COW"

p "kind delete cluster"
