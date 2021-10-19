#!/bin/bash
source /vagrant/lib.sh


kubernetes_dashboard_tag="${1:-v2.4.0}"; shift || true
kubernetes_dashboard_url="https://raw.githubusercontent.com/kubernetes/dashboard/$kubernetes_dashboard_tag/aio/deploy/recommended.yaml"


# install the kubernetes dashboard.
# NB this installs in the kubernetes-dashboard namespace.
# see https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
# see https://github.com/kubernetes/dashboard/releases
title 'Installing the Kubernetes Dashboard'
kubectl apply -f "$kubernetes_dashboard_url"

# create the admin user.
# see https://github.com/kubernetes/dashboard/wiki/Creating-sample-user
# see https://github.com/kubernetes/dashboard/wiki/Access-control
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin
    namespace: kubernetes-dashboard
EOF
# save the admin token.
kubectl \
  -n kubernetes-dashboard \
  get \
  secret \
  $(kubectl -n kubernetes-dashboard get secret | grep admin-token- | awk '{print $1}') \
  -o json | jq -r .data.token | base64 --decode \
  >/vagrant/shared/admin-token.txt


# expose the kubernetes dashboard as a node port.
# see kubectl get -n kubernetes-dashboard service/kubernetes-dashboard -o yaml
kubectl apply -n kubernetes-dashboard -f - <<'EOF'
---
# see https://kubernetes.io/docs/concepts/services-networking/service/#nodeport
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#service-v1-core
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#serviceport-v1-core
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard
spec:
  type: NodePort
  selector:
    k8s-app: kubernetes-dashboard
  ports:
    - name: https
      nodePort: 30443
      port: 443
      protocol: TCP
      targetPort: 8443
EOF
