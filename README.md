# kubethanos
kubethanos kills half of your pods randomly to engineer chaos in your preferred environment, gives you the opportunity to see how your system behaves under failures. 

## Demo in cloud using Katacoda
https://katacoda.com/mxnxpx/courses/kubernetes/kubethanos-kind

## Demo locally using Multipass
```
#launch multipass
bash multipass-setup.sh
#shell in
multipass shell ubuntu-multipass-kubethanos
#change directories to mount and launch demo
cd kind-kubethanos
bash kind-kubethanos-demo.sh 
```

## Recorded Demo
![kubethanos in action](./kind-kubethanos-demo.gif)

## Table of Contents
- [Demo](#demo)
- [Usage](#usage)
  * [Valid Parameters](#applying)
- [Acknowledgements](#acknowledgements)  
- [Disclaimer](#disclaimer)  

## Demo
```
## (optional) build from dockerfile
docker build -t docker.local/kubethanos:1.0 .
docker save --output kubethanos.tar docker.local/kubethanos:1.0

## setup a cluster
kind create cluster --config=./kind-config-1m2w-ingress.yaml

## deploy some innocent workload to the cluster
kubectl create deployment nginx --image=nginx && kubectl scale deployment/nginx --replicas=5

## verify working
kubectl get nodes -o wide
kubectl -n default get deploy,pods -o wide

## lets test draining a node
watch 'kubectl get -n default deploy; echo; kubectl -n default get pods -o wide --sort-by=.status.startTime'
kubectl drain kind-worker --ignore-daemonsets
kubectl uncordon kind-worker

## load the image into kind nodes
kind load image-archive kubethanos.tar
#or
#kind load docker-image docker.local/kubethanos:1.0

## scale up the innocent workload some more
kubectl scale deployment/nginx --replicas=10

## verify working
kubectl -n default get deploy,pods -o wide

## deploy the yaml spec
kubectl apply -f kubethanos.yaml

## snap!
watch 'kubectl get -n default deploy; echo; kubectl -n default get pods -o wide --sort-by=.status.startTime'
kubectl -n kube-system logs deploy/thanoskube -f

##--------------
## APPENDIX
##--------------
## if using k3s, here is how to load the image into the cluster
docker save --output kubethanos.tar docker.local/kubethanos:1.0
sudo k3s ctr images import kubethanos.tar 

```

## Usage

See the `kubethanos.yaml` file for an example run. Here are the list of valid parameters:

```
--namespaces=!kubesystem,foo-bar // A namespace or a set of namespaces to restrict kubethanos
--included-pod-names=<pod(s)_will_be_selected_if_pod_name_contains_this_string>
--node-names=<pod(s)_will_be_selected_if_they_reside_in_given_node_names>
--excluded-pod-names=<pod(s)_will_be_excluded_if_pod_name_contains_this_string>
--master // The address of the Kubernetes cluster to target, if none looks under $HOME/.kube
--kubeconfig // Path to a kubeconfig file
--healthcheck // Listens this endpoint for healthcheck
--interval // Interval between killing pods
--dry-run // If true, print out the pod names without actually killing them. Defaults *FALSE*
--ratio // ratio of pods to kill. Default is 0.5 
--debug // Enable debug logging.
```

* Pods to kill will be searched with a top-down approach. Node(s) first Pod(s) later.

* Configure kubernetes readiness & liveliness probes to `/healthz` endpoint.


## Acknowledgements

* I built an implementation off of the original project here: https://github.com/berkay-dincer/kubethanos


## Disclaimer

* You are responsible for your actions. If you break things in production while using this software I cannot help you to restore the damage caused.  


