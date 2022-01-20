#!/usr/bin/env bash

set -x
set -e

echo $1

# PATH_TO_LOCAL_FYBRIK=/home/mohammadtn/data-movement-operator/fybrik
# PATH_TO_LOCAL_FYBRIK=$1
# WORKING_DIR=/home/mohammadtn/hello-world-read-module/test-script
# WORKING_DIR=$2
# path to file containing access_key secert_key env var exports
EXPORT_FILE=test-script/export.sh
# EXPORT_FILE=$3
source ${EXPORT_FILE}

if [ $1 == "kind19" ]
then
    # cd ${PATH_TO_LOCAL_FYBRIK}/hack/tools
    # # ./install_kind.sh
    # ./create_kind.sh cleanup
    # kind delete cluster
    # ./create_kind.sh
    kind delete cluster
    kind create cluster --image=kindest/node:v1.19.11

else
    kind delete cluster
    kind create cluster --image=kindest/node:v1.21.1
fi


#quick start

helm repo add jetstack https://charts.jetstack.io
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add fybrik-charts https://fybrik.github.io/charts
helm repo update


helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --version v1.2.0 \
    --create-namespace \
    --set installCRDs=true \
    --wait --timeout 120s

# if [ $2 == "dev" ]
# then
#     cd ${PATH_TO_LOCAL_FYBRIK}
#     helm dependency update charts/vault
#     helm install vault charts/vault --create-namespace -n fybrik-system \
#         --set "vault.injector.enabled=false" \
#         --set "vault.server.dev.enabled=true" \
#         --values charts/vault/env/dev/vault-single-cluster-values.yaml
#     kubectl wait --for=condition=ready --all pod -n fybrik-system --timeout=120s

# else
    helm install vault fybrik-charts/vault --create-namespace -n fybrik-system \
        --set "vault.injector.enabled=false" \
        --set "vault.server.dev.enabled=true" \
        --values https://raw.githubusercontent.com/fybrik/fybrik/v$3/charts/vault/env/dev/vault-single-cluster-values.yaml
    kubectl wait --for=condition=ready --all pod -n fybrik-system --timeout=120s
# fi



helm install fybrik-crd fybrik-charts/fybrik-crd -n fybrik-system --version v$3 --wait
helm install fybrik fybrik-charts/fybrik -n fybrik-system --version v$3 --wait


# cd ${PATH_TO_LOCAL_FYBRIK}
# helm install fybrik-crd charts/fybrik-crd -n fybrik-system --wait
# helm install fybrik charts/fybrik --set global.tag=master --set global.imagePullPolicy=Always -n fybrik-system --wait


# hello-world-read-module
# kubectl apply -f hello-world-read-module/hello-world-read-module.yaml -n fybrik-system
# kubectl apply -f https://raw.githubusercontent.com/fybrik/hello-world-read-module/main/hello-world-read-module.yaml -n fybrik-system


kubectl apply -f https://github.com/fybrik/hello-world-read-module/releases/download/v$4/hello-world-read-module.yaml -n fybrik-system


# Notebook sample

kubectl create namespace fybrik-notebook-sample
kubectl config set-context --current --namespace=fybrik-notebook-sample


kubectl apply -f https://raw.githubusercontent.com/fybrik/hello-world-read-module/releases/$4/sample_assets/assetMedals.yaml -n fybrik-notebook-sample
kubectl apply -f https://raw.githubusercontent.com/fybrik/hello-world-read-module/releases/$4/sample_assets/secretMedals.yaml -n fybrik-notebook-sample
kubectl apply -f https://raw.githubusercontent.com/fybrik/hello-world-read-module/releases/$4/sample_assets/assetBank.yaml -n fybrik-notebook-sample
kubectl apply -f https://raw.githubusercontent.com/fybrik/hello-world-read-module/releases/$4/sample_assets/secretBank.yaml -n fybrik-notebook-sample


kubectl -n fybrik-system create configmap sample-policy --from-file=$WORKING_DIR/sample-policy-$4.rego
kubectl -n fybrik-system label configmap sample-policy openpolicyagent.org/policy=rego
# while [[ $(kubectl get cm sample-policy -n fybrik-system -o 'jsonpath={.metadata.annotations.openpolicyagent\.org/policy-status}') != '{"status":"ok"}' ]]; sleep 5; done --timeout=120s

while [[ $(kubectl get cm sample-policy -n fybrik-system -o 'jsonpath={.metadata.annotations.openpolicyagent\.org/policy-status}') != '{"status":"ok"}' ]]
do
    echo "waiting"
    ((c++)) && ((c==25)) && break
    sleep 5
done

# timeout 5 bash -c -- 'while true; do printf ".";done'


kubectl apply -f https://raw.githubusercontent.com/fybrik/hello-world-read-module/releases/$4/fybrikapplication.yaml -n default

while [[ $(kubectl get fybrikapplication my-notebook -n default -o 'jsonpath={.status.ready}') != "true" ]]
do
    echo "waiting"
    ((c++)) && ((c==25)) && break
    sleep 5
done


kubectl get pods -n fybrik-blueprints

POD_NAME=$(kubectl get pods -n fybrik-blueprints -o=name | sed "s/^.\{4\}//")

kubectl logs ${POD_NAME} -n fybrik-blueprints > res.out

DIFF=$(diff $WORKING_DIR/expected.txt res.out)
if [ "${DIFF}" == "" ]
then
    echo "test succeeded"
else
    echo "test failed"
fi
# diff $WORKING_DIR/expected.txt res.out

