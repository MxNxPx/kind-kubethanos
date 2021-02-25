#!/bin/bash
NAME=ubuntu-multipass-kubethanos
IMAGE=18.04
CPU=2
MEM=3G
DISK=10G

## unset any proxy env vars
unset PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

## install commands here
cat <<'EOF' > multipass-commands.txt
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq git wget pv tmux cowsay
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt install -y docker-ce
sudo usermod -aG docker ubuntu
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
bash get_helm.sh
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo touch /etc/apt/sources.list.d/kubernetes.list
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
curl -O https://storage.googleapis.com/golang/go1.13.linux-amd64.tar.gz
echo "export GOPATH=$HOME/go" >> ~/.bashrc
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bashrc
tar -xf go1.13.linux-amd64.tar.gz
sudo chown -R root:root ./go
sudo mv go /usr/local
GO111MODULE="on" /usr/local/go/bin/go get -u -v sigs.k8s.io/kind
echo -e "\nfunction tmuxdemo() { \n  tmux new-session -s demo \;  split-window -v -p 15 \;  select-pane -t 0 \;  resize-pane -Z \; \n}" >> ~/.bashrc
echo -e "\nPS1=\"$ \"" >> ~/.bashrc
echo -e "setw -g mode-keys vi\nset -g mouse on" >> ~/.tmux.conf
EOF

## launch multipass
multipass launch $IMAGE --name $NAME --cpus $CPU --mem $MEM --disk $DISK
sleep 10
multipass list | egrep "^ubuntu-multipass.*Running.*([0-9]{1,3}[\.]){3}[0-9]{1,3}"
if [ $? -ne 0 ]; then
   echo "[!] multipass instance failed to create, run command below and try again:"
   echo "    #  multipass delete ubuntu-multipass && multipass purge"
   exit 1
fi

## loop thru commands
OLDIFS=$IFS
IFS=$'\n'
echo "[*] `date` -- RUNNING THRU INSTALLS ..."
for line in $(cat multipass-commands.txt); do
  echo "[*] $line"
  multipass exec $NAME -- bash -c ''"$line"''
done
echo "[*] `date` -- DONE WITH INSTALLS ..."
IFS=$OLDIFS
rm multipass-commands.txt

## mount current dir into the multipass instance
multipass mount . $NAME:/home/ubuntu/kind-kubethanos
