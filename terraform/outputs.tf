output "github_actions_key" {
  value     = google_service_account_key.github_actions_key.private_key
  sensitive = true
}
