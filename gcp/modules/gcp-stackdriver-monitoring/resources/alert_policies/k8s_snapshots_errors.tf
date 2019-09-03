resource "google_monitoring_alert_policy" "k8s_snapshots_errors" {
  display_name = "IAM audit logs do not contain policy modification events"
  combiner     = "OR"

  conditions {
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/k8s_snapshots.error\" resource.type=\"k8s_container\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1.0
      duration        = "900s"

      trigger {
        count   = 0
        percent = 0
      }

      aggregations {
        alignment_period     = "600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_NONE"
        group_by_fields      = []
      }

      denominator_filter       = ""
      denominator_aggregations = []
    }

    display_name = "Error found in K8s-snapshots logs"
  }

  documentation = {
    content   = "[Use this link to explore policy events in Logs Viewer](https://console.cloud.google.com/logs/viewer?project=${project_id}&minLogLevel=0&expandAll=false&interval=PT1H&advancedFilter=resource.type%3D%22k8s_container%22%20AND%20resource.labels.container_name%3D%22k8s-snapshots%22%20AND%20textPayload:%22Error:%20%22)"
    mime_type = "text/markdown"
  }

  notification_channels = []
  user_labels           = {}
  enabled               = "true"
}
