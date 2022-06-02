# Create the storage bucket and bucket object for the function source code
resource "google_storage_bucket" "cf_bucket" {
  location = var.region
  name     = "cf-code-storage-bucket"
}

data "archive_file" "cf_code_object_zip" {
  type        = "zip"
  source_dir  = "${path.root}/function_source/"
  output_path = "${path.root}/function_source.zip"
}

resource "google_storage_bucket_object" "cf_code_object" {
  bucket = google_storage_bucket.cf_bucket.name
  name   = "function_source.zip"
  source = data.archive_file.cf_code_object_zip.output_path
}

resource "google_cloudfunctions_function" "function" {
  name        = "my-function"
  description = "My function"
  runtime     = "python39"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.cf_bucket.name
  source_archive_object = google_storage_bucket_object.cf_code_object.name
  trigger_http          = true
  entry_point           = "main"

  service_account_email = google_service_account.function_sa.email

  secret_environment_variables {
    key     = "SECRET_KEY"
    secret  = google_secret_manager_secret.cf_secret.secret_id
    version = "latest"
  }
}