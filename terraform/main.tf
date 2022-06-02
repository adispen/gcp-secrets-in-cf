# Define all secret manager resources
# Recommended to deploy this first and set your secret version before deploying the cloud function
resource "google_secret_manager_secret" "cf_secret" {
  secret_id = "cloud-function-secret"

  replication {
    automatic = true
  }
}

resource "google_service_account" "function_sa" {
  account_id  = "cloud-function-service-account"
  description = "A Service Account for our Cloud Function"
}

resource "google_project_iam_member" "function_sa_secret_binding" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.function_sa.email}"
  role    = "roles/secretmanager.secretAccessor"

  condition {
    title       = "restricted_to_secret"
    description = "Allows access only to the desired secret"
    expression  = "resource.name.startsWith(\"${google_secret_manager_secret.cf_secret.name}\")"
  }
}