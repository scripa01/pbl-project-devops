resource "helm_release" "eso" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.14.2"
}

resource "google_service_account" "eso_sa" {
  account_id   = "eso-sa"
  display_name = "External Secrets Operator SA"
}

resource "google_project_iam_member" "eso_secret_access" {
  project = local.project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso_sa.email}"
}

resource "kubernetes_service_account" "eso_ksa" {
  metadata {
    name      = "eso-sa"
    namespace = "apis"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.eso_sa.email
    }
  }
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.eso_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${local.project}.svc.id.goog[external-secrets/eso-sa]"
  ]
}

resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "gcp-secret-store"
      namespace = "apis"
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = local.project
          auth = {
            workloadIdentity = {
              clusterName     = google_container_cluster.default.name
              clusterLocation = google_container_cluster.default.location
              serviceAccountRef = {
                name = kubernetes_service_account.eso_ksa.metadata[0].name
              }
            }
          }
        }
      }
    }
  }
}


