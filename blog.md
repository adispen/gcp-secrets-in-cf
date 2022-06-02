# Utilizing GCP Secret Manager Secrets in Cloud Functions with Terraform

Whether you are writing a quick function to hit an API or developing the backend of your very own API, you will
inevitably need to reference some form of secret within your serverless Cloud Function.  Up until now this was 
accomplished in any number of ways, ranging from encoded environment variables to mounted volumes.  In a recent update 
though, GCP Cloud Functions can now natively pull from Secret Manager allowing for a more secure and auditable way to 
manage access from serverless functionality in your cloud environment.

As of version `4.11.0` of the `google` Terraform provider, this functionality is now also available as part of your 
Infrastructure as Code deployment.  The following is a basic example of how to implement everything you might need
to create and reference a Secret Manager secret securely from your Cloud Function using Terraform.

Our only assumption here is that you have an environment ready to go with all the necessary APIs enabled and the 
permissions to affect changes in said environment.

## Secret Manager

To start, we'll need to set up the [Secret Manager secret Terraform resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret). 
You can name it and set up replications and zones however you see fit. Remember that you'll need to manually upload this
secret in the console or use the [Secret Version resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version),
though that has its own considerations you can read about [here](https://registry.terraform.io/language/state/sensitive-data).

```hcl
resource "google_secret_manager_secret" "cf_secret" {
  secret_id = "cloud-function-secret"
  
  replication {
    automatic = true
  }
}
```

Next we'll need to configure the IAM permissions for accessing this secret.  There's a few ways to do this in Terraform
but they essentially accomplish the same functionality.

Regardless of our methodology we first need to create a Service Account for our function:
```hcl
resource "google_service_account" "function_sa" {
  account_id  = "cloud-function-service-account"
  description = "A Service Account for our Cloud Function"
}
```

Now we can bind that account to have special permissions for accessing only our secret, there are two ways to do this. 
Either implementation is fine, just follow the conventions of your existing Terraform codebase.

1. IAM Conditions:
   ```hcl
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
   ```
2. Secret Manager IAM Binding
   ```hcl
   resource "google_secret_manager_secret_iam_binding" "function_sa_secret_binding" {
    project   = var.project_id
    secret_id = google_secret_manager_secret.cf_secret.secret_id
    role      = "roles/secretmanager.secretAccessor"
    members   = [
      "serviceAccount:${google_service_account.function_sa.email}",
    ]
   }
   ```

**Note:** You should deploy the secret resource first, and create the secret version as you see fit *before* deploying
the Cloud Function.  If you attempt to deploy the Cloud Function while there is no appropriate secret version present
the deployment will fail.

## Cloud Function

Now we need to actually create our function resource.  How you are managing your source code doesn't really matter here since the
Secret Manager reference is directly in the function resource.

```hcl
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
```

Notably here we have to pass the `secret_id` attribute **instead of** the `id` or `name` of the secret, as the Terraform 
documenatation describes.  The provider will construct the full resource path based on the project ID supplied to the 
SDK concatenated with the `secret_id`. Providing the other attributes will instead create an invalid resource path. 

If your 
secret is in another project, you will need to also pass in a `project_id` field, though this is limited to the actual 
project ID number and not name. Otherwise it is assumed the secret and function live in the same project.  To learn more 
about the project based limitations of this functionality be sure to check the [official Terraform docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function#nested_secret_environment_variables).

When it comes to actually referencing your secret with your function code, it will look exactly the same as when using
an environment variable with `os.environ.get()`.  As an example here is a brief python snippet of a function handler 
that would reference the secret we pulled in using the above Terraform code:

```python
import os

def main(request):
    our_secret = os.environ.get('SECRET_KEY')
    if our_secret:
        return 'OK'
    else:
        print("The secret was not found, exiting.")
        return None
```

Now you have a function that securely accesses your secrets via Secret Manager without having to mount any external volumes
or use any external tooling, all while being managed through Terraform!

## Required APIs
Be sure to enable the following in your desired project in order to use the features described in this blog.
* Cloud Build API
* Cloud Functions API
* Cloud Logging API
* Cloud Pub/Sub API
* Secret Manager API

## Links and References
* [This blog as a repository, with code samples](https://github.com/adispen/gcp-secrets-in-cf)
* [GCP Cloud Function Terraform Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function)
* [GCP Secret Manager Secrets Terraform Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret)
* [GCP Secret Manager Best Practices Docs](https://cloud.google.com/secret-manager/docs/best-practices)