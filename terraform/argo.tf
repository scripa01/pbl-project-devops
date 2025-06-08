# [START gke_quickstart_autopilot_app]
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.default.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.default.master_auth[0].cluster_ca_certificate)

  ignore_annotations = [
    "^autopilot\\.gke\\.io\\/.*",
    "^cloud\\.google\\.com\\/.*"
  ]
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.0.15"

  namespace = "argocd"

  create_namespace = true

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}


data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = helm_release.argocd.namespace
  }
}


resource "helm_release" "argocd_image_updater" {
  name      = "argocd-image-updater"
  namespace = "argocd"

  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "0.12.2"

  values = [
    <<EOF
serviceAccount:
  create: false
  name: argocd-image-updater-sa

config:
  registries:
    - name: GCP Artifact Registry
      api_url: https://europe-north1-docker.pkg.dev
      prefix: europe-north1-docker.pkg.dev
      credentials: ext:/auth/auth.sh
      credsexpire: 30m
volumes:
- configMap:
    defaultMode: 0755
    name: auth-cm
  name: auth
volumeMounts:
- mountPath: /auth
  name: auth
EOF
  ]
}

resource "kubernetes_config_map" "auth_cm" {
  metadata {
    name      = "auth-cm"
    namespace = "argocd"
  }

  data = {
    "auth.sh" = <<EOF
#!/bin/sh
ACCESS_TOKEN=$(wget --header 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token -q -O - | grep -Eo '"access_token":.*?[^\\]",' | cut -d '"' -f 4)
echo "oauth2accesstoken:$ACCESS_TOKEN"
EOF
  }
}


resource "google_service_account" "app_sa" {
  account_id   = "argocd-image-updater-sa"
  display_name = "argocd-image-updater-sa"
}

resource "kubernetes_service_account" "ksa" {
  metadata {
    name      = "argocd-image-updater-sa"
    namespace = "argocd"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.app_sa.email
    }
  }
}

resource "google_project_iam_member" "artifactregistry_repoAdmin" {
  project = local.project
  role    = "roles/artifactregistry.repoAdmin"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_service_account_iam_binding" "argo_workload_identity_binding" {
  service_account_id = google_service_account.app_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members            = ["serviceAccount:${local.project}.svc.id.goog[argocd/argocd-image-updater-sa]"]
}

resource "kubernetes_namespace" "apis" {
  metadata {
    name = "apis"
  }
}




