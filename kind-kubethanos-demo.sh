#!/bin/bash

. ./demo-magic.sh
clear;echo;echo;
PROMPT_TIMEOUT=0
MSG="LET'S GET THIS DEMO STARTED..."
COW="/usr/share/cowsay/cows/default.cow"
pe "echo \$MSG | cowsay -f \$COW"

## create kind cluster
echo;echo
p "[.] kind"
pei "kubectl cluster-info"
echo;echo
pei "docker ps"
echo;echo
pei "time (kind create cluster --config ./kind-config-1m2w-ingress.yaml --image kindest/node:v1.18.2 --wait 5m && kubectl wait --timeout=5m --for=condition=Ready nodes --all)"
pei "docker ps -a --format \"table {{.Names}}\\\t{{.Image}}\\\t{{.Status}}\""

## view cluster status
pe "kubectl get nodes -o wide"
pe "kubectl get pods -A"

## try to deploy old deployment spec
echo;echo
p "[.] k8s deployment and pod placement"
pei "cat nginx-deployment.yaml"
pe "kubectl -n default apply -f nginx-deployment.yaml; kubectl -n default wait deploy/nginx --for=condition=available --timeout=120s"

## verify working
pe "kubectl -n default get deploy,pods -o wide"

## lets test draining a node
p "[*] in another window:  watch -t 'kubectl get -n default deploy; echo; kubectl -n default get pods -o wide --sort-by=.status.startTime'"
pe "kubectl drain kind-worker --ignore-daemonsets"
pe "kubectl uncordon kind-worker"

echo;echo
p "[.] kubethanos"

## load the image into kind nodes
pe "kind load image-archive kubethanos.tar"
#or
#kind load docker-image docker.local/kubethanos:1.0

## scale up the innocent workload some more
pe "kubectl -n default scale deployment/nginx --replicas=10; kubectl -n default wait deploy/nginx --for=condition=available --timeout=120s"

## verify working
pe "kubectl -n default get deploy,pods -o wide"

## prepare for the snap!
p "[*] in another window:  watch -t 'kubectl get -n default deploy; echo; kubectl -n default get pods -o wide --sort-by=.status.startTime'"
p "[*] in another window (execute after deploying kubethanos):  kubectl -n kube-system logs deploy/thanoskube -f"

## deploy the yaml spec
pe "kubectl apply -f kubethanos-infinitywar.yaml; kubectl -n kube-system wait deploy/thanoskube --for=condition=available --timeout=120s"

## what will happen this time?
pe "kubectl delete -f kubethanos-infinitywar.yaml"
p "[*] in another window (execute after re-deploying kubethanos):  kubectl -n kube-system logs deploy/thanoskube -f"
pe "kubectl apply -f kubethanos-endgame.yaml"

PROMPT_TIMEOUT=0
echo;echo
MSG="THE WORK IS DONE."
COW="./thanos.cow"
pe "echo \$MSG | cowsay -f \$COW"

pe "kind delete cluster"
