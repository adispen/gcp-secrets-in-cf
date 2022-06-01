# Utilizing GCP Secret Manager Secrets in Cloud Functions with Terraform

Whether you are writing a quick function to hit an API or developing the backend of your very own API, you will
inevitably need to reference some form of secret within your serverless Cloud Function.  Up until now this was 
accomplished in any number of ways, ranging from encoded environment variables to mounted volumes.  In a recent update 
though, GCP Cloud Functions can now natively pull from Secret Manager allowing for a more secure and auditable way to 
manage access from serverless functionality in your cloud environment.

As of version 4.11.0 of the `google` Terraform provider, this functionality is now also available as part of your 
Infrastructure as Code deployment.  The following is a basic example of how to implement everything you might need
to create and reference a Secret Manager secret securely from your Cloud Function.

Our only assumption here is that you have an environment ready to go with all the necessary APIs enabled and the 
permissions to affect changes in said environment.

## Secret Manager

To start, we'll need to set up the [secret in Secret Manager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret). 
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

Regardless of our methodology we need to create a Service Account for our Function:
```hcl
resource "google_service_account" "function_sa" {
  account_id = "cloud-function-service-account"
  description = "A Service Account for our Cloud Function"
}
```

Now we can bind that account to have special permissions for accessing only our secret, there are two ways to do this. 
Either implementation is fine, just follow the conventions for your existing Terraform codebase

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

## Cloud Function

Now we need to actually create the function.  How you are managing your source code doesn't really matter here since the
secret manager reference is directly in the function resource.

