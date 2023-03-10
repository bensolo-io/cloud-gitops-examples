locals {
  argoEnabled = var.argocd != null && var.argocd != {} && length(try(var.argocd.valueFiles, "0")) > 0

  kubectl = <<EOT
aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name}
kubectl create ns argocd
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd
kubectl apply -f - <<EOM
${local.manifest}
EOM
EOT

  kubectlTrigger = "${sha1(local.manifest)}-${sha1(local.kubectl)}"

  manifest = templatefile(
    "${path.module}/app.tftpl",
    {
      name       = aws_eks_cluster.eks.name
      repo       = try(var.argocd.repo, "")
      path       = try(var.argocd.path, "")
      revision   = try(var.argocd.revision, "")
      valueFiles = try(var.argocd.valueFiles, [])
      values = try(yamldecode(<<EOT
    global:
      external-secrets:
        serviceAccount:
          create: true
          name: external-secrets
          annotations:
            eks.amazonaws.com/role-arn: ${module.iam-assumable-role-ext-secrets.iam_role_arn}
      aws-load-balancer-controller:
        clusterName: ${aws_eks_cluster.eks.name}
        serviceAccount:
          create: true
          name: aws-load-balancer-controller
          annotations:
            eks.amazonaws.com/role-arn: ${module.iam-assumable-role-aws-lb-controller.iam_role_arn}
      gloo-mesh-enterprise:
        glooMeshMgmtServer:
          serviceAccount:
            extraAnnotations:
              eks.amazonaws.com/role-arn: ${module.iam-assumable-role-gloo-mgmt-server.iam_role_arn}
EOT
  ), "") })


}


resource "null_resource" "kubectl" {
  count = local.argoEnabled ? 1 : 0
  triggers = {
    hash    = local.kubectlTrigger
    cluster = aws_eks_cluster.eks.name
  }

  # external commands are required to keep the eks cluster creation and k8s resource creation 
  # in the same module; if you were to use the eks auth resource and kubernetes provider here, it would
  # work the first time the cluster is created, but after that session expires it will no longer be to
  # reach your cluster unless you point epxlicitly to local kubeconfig
  provisioner "local-exec" {
    command = local.kubectl
  }
  # provisioner "local-exec" {
  #   when    = destroy
  #   command = <<-EOD
  # aws eks update-kubeconfig --name ${self.triggers.cluster}
  # kubectl delete apps --all -n argocd
  # kubectl delete -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml -n argocd
  # kubectl delete ns argocd
  # EOD
  # }
}
