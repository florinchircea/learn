```shell
source <(kind completion bash)
source <(kubectl completion bash)
source <(helm completion bash)
```

# Install metrics server

```shell
helm upgrade --install metrics-server metrics-server \
    --repo https://kubernetes-sigs.github.io/metrics-server/ \
    --version 3.8.3 \
    --create-namespace \
    --namespace metrics-server \
    --set args={--kubelet-insecure-tls}

```

# Install Minio\

```shell
helm upgrade --install minio minio \
  --version 8.0.10 \
  --repo https://helm.min.io/ \
  --create-namespace \
  --namespace minio \
  --set accessKey=admin,secretKey=minioadmin123 \
  --set buckets[0].name=loki-data \
  --set buckets[0].policy=none \
  --set buckets[0].purge=false 

```

# Loki distributed

```shell
cat << EOF > values-loki-distributed.yaml
loki:
  structuredConfig:
    ingester:
      # Disable chunk transfer which is not possible with statefulsets
      # and unnecessary for boltdb-shipper
      max_transfer_retries: 0
      chunk_idle_period: 1h
      chunk_target_size: 1536000
      max_chunk_age: 1h
  storageConfig:
    boltdb_shipper:
      shared_store: s3
    aws:
      endpoint: http://minio.minio:9000
      s3forcepathstyle: true
      access_key_id: admin
      secret_access_key: minioadmin123
      insecure: true
      bucketnames: "loki-data"
    filesystem: null
  schema_config:
    configs:
      - from: 2023-02-01
        store: boltdb-shipper
        object_store: aws
        schema: v11
        index:
          prefix: loki_
          period: 1h
ingester:
  persistence:
    enabled: true
    size: 10Gi
querier:
  persistence:
    enabled: true
    size: 10Gi
EOF

helm upgrade --install loki-distributed loki-distributed \
  --version 0.69.4 \
  --repo https://grafana.github.io/helm-charts \
  --create-namespace \
  --namespace loki \
  --values values-loki-distributed.yaml

```

# Install promtail

```shell
cat << EOF > values-promtail.yaml
config:
  clients:
    - url: "http://loki-distributed-gateway.loki/loki/api/v1/push"
EOF

helm upgrade --install promtail promtail \
  --version 6.8.2 \
  --repo https://grafana.github.io/helm-charts \
  --create-namespace \
  --namespace promtail \
  --values values-promtail.yaml

```

# Install Grafana

```shell

cat << EOF > values-grafana.yaml
persistence:
  enabled: true
  size: 10Gi
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: "http://loki-distributed-gateway.loki"
EOF

helm upgrade --install grafana grafana \
  --version 6.50.7 \
  --repo https://grafana.github.io/helm-charts \
  --create-namespace \
  --namespace grafana \
  --values values-grafana.yaml

# Admin password
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

```
# TODO
## Install prometheus stack
helm upgrade --install prometheus kube-prometheus-stack \
    --repo https://prometheus-community.github.io/helm-charts \
    --version 44.3.1 \
    --create-namespace \
    --namespace monitoring 


## K6


kubectl create deployment nginx2 --image nginx:alpine
kubectl expose deployment nginx2 --port=80

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: /foo(/|$)(.*)
        backend:
          service:
            name: nginx2
            port:
              number: 80
EOF

docker run --rm -i --env MY_DOMAIN="flo-desktop/foo" -w /work -u 0 -v $PWD:/work grafana/k6 run --vus 10000 --duration 10s /work/k6/script.js