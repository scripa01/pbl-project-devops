variable "postgres_instances" {
  type = list(object({
    name    = string
    db_name = string
  }))
  default = [
    {
      name    = "board-db"
      db_name = "board-task"
    },
    {
      name    = "auth-db"
      db_name = "authorization-user-api"
    },
    {
      name    = "org-db"
      db_name = "organization_project_user"
    }
  ]
}

data "google_secret_manager_secret_version" "postgres_passwords" {
  for_each = { for inst in var.postgres_instances : inst.name => inst }

  secret  = "${each.key}-password"
  project = local.project
  version = "latest"
}

resource "google_sql_database_instance" "postgres" {
  for_each = { for inst in var.postgres_instances : inst.name => inst }

  name             = each.key
  database_version = "POSTGRES_15"
  region           = "europe-north1"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.default.id
    }
  }

  deletion_protection = false
}

resource "google_sql_user" "default" {
  for_each = { for inst in var.postgres_instances : inst.name => inst }

  name     = "postgres"
  instance = google_sql_database_instance.postgres[each.key].name
  password = data.google_secret_manager_secret_version.postgres_passwords[each.key].secret_data
}

resource "google_sql_database" "db" {
  for_each = { for inst in var.postgres_instances : inst.name => inst }

  name     = each.value.db_name
  instance = google_sql_database_instance.postgres[each.key].name
}
