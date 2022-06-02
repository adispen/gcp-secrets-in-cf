# Your provider version should be the latest, with 4.11.0 being the absolute minimum for secret manager reference functionality
# As always, set your remote state as you see fit elsewhere
provider "google" {
  project = var.project_id
  region  = var.region
}