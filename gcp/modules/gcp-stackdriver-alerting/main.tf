terraform {
  backend "gcs" {}
}

variable "nonce" {}
variable "domain_name" {}
variable "project_id" {}
variable "serviceaccount_key" {}

# Terragrunt variable
variable "ssl_enabled_uptime_checks" {}

# Enables debug mode when TF_VAR_stackdriver_debug is not empty
variable "stackdriver_debug" {
  default = ""
}

resource "template_dir" "resources" {
  source_dir      = "${path.cwd}/resources"
  destination_dir = "${path.cwd}/resources_rendered"

  vars {
    project_id                = "${var.project_id}"
    domain_name               = "${var.domain_name}"
    ssl_enabled_uptime_checks = "${var.ssl_enabled_uptime_checks}"
  }
}

resource "null_resource" "apply_stackdriver_alerting" {
  depends_on = ["template_dir.resources"]

  triggers = {
    nonce = "${var.nonce}"
  }

  provisioner "local-exec" {
    command = <<EOF
      export PROJECT_ID=${var.project_id}
      export GOOGLE_CLOUD_KEYFILE=${var.serviceaccount_key}
      export STACKDRIVER_DEBUG=${var.stackdriver_debug}

      RETRIES=5
      RETRY_COUNT=1
      while [ "$STACKDRIVER_DID_NOT_FAIL" != "true" ]; do
        STACKDRIVER_DID_NOT_FAIL="true"
        echo "[Try $RETRY_COUNT of $RETRIES] Applying Stackdriver resources..."
        ruby -e '
          require "${path.module}/client.rb"
          apply_resources
        '
        if [ "$?" != "0" ]; then
          STACKDRIVER_DID_NOT_FAIL="false"
        fi

        RETRY_COUNT=$(($RETRY_COUNT+1))
        if [ "$RETRY_COUNT" -eq "$RETRIES" ]; then
          echo "Retry limit reached, giving up!"
          EXIT_STATUS=1
        fi
        if [ "$STACKDRIVER_DID_NOT_FAIL" == "false" ]; then
          sleep 10
        fi
      done
    EOF
  }
}

resource "null_resource" "destroy_stackdriver_alerting" {
  depends_on = ["template_dir.resources"]

  provisioner "local-exec" {
    when = "destroy"

    command = <<EOF
      export PROJECT_ID=${var.project_id}
      export GOOGLE_CLOUD_KEYFILE=${var.serviceaccount_key}

      RETRIES=5
      RETRY_COUNT=1
      while [ "$STACKDRIVER_DID_NOT_FAIL" != "true" ]; do
        STACKDRIVER_DID_NOT_FAIL="true"
        echo "[Try $RETRY_COUNT of $RETRIES] Destroying Stackdriver resources..."
        ruby -e '
          require "${path.module}/client.rb"
          destroy_resources
        '
        if [ "$?" != "0" ]; then
          STACKDRIVER_DID_NOT_FAIL="false"
        fi

        RETRY_COUNT=$(($RETRY_COUNT+1))
        if [ "$RETRY_COUNT" -eq "$RETRIES" ]; then
          echo "Retry limit reached, giving up!"
          EXIT_STATUS=1
        fi
        if [ "$STACKDRIVER_DID_NOT_FAIL" == "false" ]; then
          sleep 10
        fi
      done
    EOF
  }
}
