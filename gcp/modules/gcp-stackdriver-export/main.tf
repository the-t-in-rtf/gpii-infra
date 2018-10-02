terraform {
  backend "gcs" {}
}

variable "project_id" {}
variable "serviceaccount_key" {}
variable "exports" {
  default = {
    # Captures interactions with many Google products, including GCE, GS, IAM,
    # and more.
    #
    # TODO: This is a lot less noisy if we add "AND NOT operation.producer=k8s.io".
    "cloudaudit-activity" = "logName=projects/__var.project_id__/logs/cloudaudit.googleapis.com%2Factivity"

    # Captures Google Storage and KMS events.
    "cloudaudit-data-access" = "logName=projects/__var.project_id__/logs/cloudaudit.googleapis.com%2Fdata_access"

    # Captures events for products within GCE, such as Snapshots, Instance
    # Groups, Firewalls, etc.
    "compute-activity" = "logName=projects/__var.project_id__/logs/compute.googleapis.com%2Factivity_log"

    # Events from GPII containers.
    "gpii-containers" = "resource.type=k8s_container AND resource.labels.namespace_name=gpii"
  }
}
variable "exported_logs_storage_class" {
  default = "REGIONAL"
}
variable "exported_logs_storage_region" {
  default = "us-central1"
}
variable "exported_logs_expire_after" {
  default = "14"
}

module "gcp_stackdriver_export" {
  source             = "/exekube-modules/gcp-stackdriver-export"
  project_id         = "${var.project_id}"
  serviceaccount_key = "${var.serviceaccount_key}"
  exports            = "${var.exports}"
  exported_logs_storage_class = "${var.exported_logs_storage_class}"
  exported_logs_storage_region = "${var.exported_logs_storage_region}"
}
