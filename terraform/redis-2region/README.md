# redis-2region

### What this module creates

* 2 vpcs (one in each region) (each with 2 az) with a peering connection
* global elasticache 2-region redis cluster with tls and auth token
* 2 eks clusters (1 in each region) with 1 m5large node
* optional redis tester pod deployment

This module does not create public redis endpoints or VPN connections.  To access redis in the cluster, use a shell in a pod.

### Validate elasticache connection

Create secret with redis details and deploy a test container (repeat this for each region / cluster):

```bash
kubectl apply -f- <<EOF
kind: Secret
apiVersion: v1
metadata:
  name: redis-config
  namespace: default
stringData:
  token: ${TF_VAR_redis_auth}
  address: `./terraform-wrapper.sh output --json | jq -r '.redis.value'`
EOF

kubectl apply -k https://github.com/bensolo-io/aws-redis-simple.git/deploy/kustomize
```

If the pod became ready it was able to set/get a key in elasticache:

```bash
kg pods -l app=redis-tester -n default
NAME                                            READY   STATUS    RESTARTS   AGE
aws-elasticache-redis-tester-854996ff6b-n72nr   1/1     Running   0          23s
```

```bash
k logs -l app=redis-tester -n default
9:52PM INF redis client created for master.solo-v0-redis-1region.sh5gsi.use2.cache.amazonaws.com:6379
9:52PM INF initial redis check OK
9:52PM INF starting container server on :8080
9:52PM DBG /liveness OK
9:52PM DBG /liveness OK
9:52PM DBG /liveness OK
```

### Cleanup

```bash
./terraform-wrapper.sh destroy
```
