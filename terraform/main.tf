locals {
  project = "problem-based-learning-462218"
}

provider "google" {
  project = local.project
  region  = "europe-north1"
}

resource "google_compute_network" "default" {
  name = "pbl-network"

  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

resource "google_compute_subnetwork" "default" {
  name = "pbl-subnetwork"

  ip_cidr_range = "10.0.0.0/16"

  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"

  network = google_compute_network.default.id
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.1.0/24"
  }
}

resource "google_container_cluster" "default" {
  name = "pbl-autopilot-cluster"

  enable_autopilot         = true
  enable_l4_ilb_subsetting = true

  network    = google_compute_network.default.id
  subnetwork = google_compute_subnetwork.default.id

  ip_allocation_policy {
    stack_type                    = "IPV4_IPV6"
    services_secondary_range_name = google_compute_subnetwork.default.secondary_ip_range[0].range_name
    cluster_secondary_range_name  = google_compute_subnetwork.default.secondary_ip_range[1].range_name
  }

  # Set `deletion_protection` to `true` will ensure that one cannot
  # accidentally delete this instance by use of Terraform.
  deletion_protection = false
}
# [END gke_quickstart_autopilot_cluster]

variable "docker_repo_names" {
  default = ["authorization-user-api", "backend-api", "board-task-api", "organization-project-user-api"]
}

resource "google_artifact_registry_repository" "repos" {
  for_each      = toset(var.docker_repo_names)
  repository_id = each.key
  description   = "Docker repo for ${each.key}"
  format        = "DOCKER"
}

resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions CI"
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = local.project
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = local.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_service_account_key" "github_actions_key" {
  service_account_id = google_service_account.github_actions.name
  private_key_type   = "TYPE_GOOGLE_CREDENTIALS_FILE"
}
