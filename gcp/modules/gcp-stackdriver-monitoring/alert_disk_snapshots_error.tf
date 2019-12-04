resource "google_monitoring_alert_policy" "disk_snapshots_error" {
  display_name = "Snapshot creation audit log does not contain errors"
  combiner     = "OR"

  conditions {
    condition_threshold {
      filter = "metric.type=\"logging.googleapis.com/user/compute.disks.createSnapshot\" resource.type=\"gce_disk\" AND metric.label.severity=\"ERROR\""

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }

      denominator_filter = "metric.type=\"logging.googleapis.com/user/compute.disks.createSnapshot\" resource.type=\"gce_disk\" AND metric.label.severity!=\"ERROR\""

      denominator_aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.05
      duration        = "0s"
    }

    display_name = "Error ratio exceeds 5% for events in snapshot creation audit log"
  }

  documentation = {
    content   = "[Use this link to explore policy events in Logs Viewer](https://console.cloud.google.com/logs/viewer?project=${var.project_id}&minLogLevel=0&expandAll=false&interval=PT1H&advancedFilter=resource.type%3D%22gce_disk%20AND%20protoPayload.methodName%3D%22v1.compute.disks.createSnapshot%22%20AND%20severity=%3D%22ERROR%22%0A)"
    mime_type = "text/markdown"
  }

  notification_channels = ["${google_monitoring_notification_channel.email.name}", "${google_monitoring_notification_channel.alerts_slack.*.name}"]
  user_labels           = {}
  enabled               = "true"

  depends_on = ["google_logging_metric.disks_createsnapshot"]
}
