# Install tools
brew install k9s
brew install kind
brew install kubectl
kind create cluster

# Install 2 instances of our service
./mvnw install -Dquarkus.container-image.build=true -Dquarkus.kubernetes.deploy=true -Dquarkus.kubernetes.namespace=default -Dquarkus.kubernetes.labels.app=quarkus -Dquarkus.kubernetes.name=quarkus-zta
./mvnw install -Dquarkus.container-image.build=true -Dquarkus.kubernetes.deploy=true -Dquarkus.kubernetes.namespace=default -Dquarkus.kubernetes.labels.app=quarkus -Dquarkus.kubernetes.name=quarkus-zta-aux

# Get the IP of our cluster node
kubectl get nodes -o wide | awk '{print $6}'

# Test without security

## Get services, use the external port e.g. 80:31591/TCP
kubectl get svc

## Check it works connecting to our service from outside
curl 172.18.0.2:31591/hello
curl 172.18.0.2:31591/echo/example

## Check it works connecting from one service to the other
## shell in the quarkus-zta pod
curl quarkus-zta-aux/hello

## Check it works connecting from inside to outside world
kubectl exec --stdin --tty quarkus-zta**** -- /bin/bash
curl --location 'https://postman-echo.com/get?var=calling-from-pod'

# Test with security
## SaSS keycloak
https://lemur-2.cloud-iam.com/auth/admin/quarkus-demo/console/

## Install istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.19.0 TARGET_ARCH=x86_64 sh -
istioctl install --set profile=demo -y

## Apply gateway, virtualservice, authn and authz
kubectl apply -f gateway.yml
kubectl apply -f virtualsvc.yml
kubectl apply -f authn.yml
kubectl apply -f authz.yml

## Check it still works from outside to inside
curl 172.18.0.2:31591/echo/hola

## Apply istio to our namespace
kubectl label namespace default istio-injection=enabled --overwrite
## kill the 2 pods to allow the sidecar creation

## Check that now we dont have access from outside
curl 172.18.0.2:31610/echo/example
curl 172.18.0.2:31591/echo/example

## Check that we don't have access even from inside the cluster
## shell in the quarkus-zta pod
curl quarkus-zta-aux/hello

## Get the token from KeyCloak
token=$(curl -d 'client_id=istio' -d 'username=quarkus' -d 'password=quarkuspwd' -d 'grant_type=password' \
    'https://lemur-2.cloud-iam.com//auth/realms/quarkus-demo/protocol/openid-connect/token' | jq .access_token)

## Check that now we have access from outside usint the Token
curl 172.18.0.2:31591/echo/example  -H "Authorization: Bearer $token"

## Check that now we have access from inside using the Token
## shell in the quarkus-zta pod
curl -d 'client_id=istio' -d 'username=quarkus' -d 'password=quarkuspwd' -d 'grant_type=password' \
    'https://lemur-2.cloud-iam.com//auth/realms/quarkus-demo/protocol/openid-connect/token'
## copy token
curl quarkus-zta-aux/hello -H "Authorization: Bearer $token"

## Restrict outbound connections to Google
kubectl apply -f svcentry.yml
kubectl edit configmap istio -n istio-system
# data.mesh.outboundTrafficPolicy.mode=REGISTRY_ONLY

# inside to outside
kubectl exec --stdin --tty quarkus-zta**** -- /bin/bash
curl --location 'https://postman-echo.com/get?var=calling-from-pod'
curl https://www.google.com

#kiali
helm install \
  --namespace istio-system \
  --set auth.strategy="anonymous" \
  --repo https://kiali.org/helm-charts \
  kiali-server \
  kiali-server
# prometheus
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/prometheus.yaml

kubectl port-forward svc/kiali 20001:20001 -n istio-system
https://localhost:20001/