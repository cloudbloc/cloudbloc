locals {
  dashboards_checksum = sha256(jsonencode(local.effective_dashboards_json))
  effective_dashboards_json = length(var.dashboards_json) > 0 ? var.dashboards_json : {
    "k8s-overview.json" = <<-EOT
    {
      "id": null,
      "uid": "k8s-overview-auto",
      "title": "Kubernetes / Prometheus Overview",
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 1,
      "refresh": "30s",
      "panels": [
        {
          "type": "stat",
          "title": "Targets Up",
          "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 },
          "options": { "reduceOptions": { "calcs": ["lastNotNull"] } },
          "targets": [{ "expr": "count(up)", "legendFormat": "up" }]
        },
        {
          "type": "timeseries",
          "title": "Up by Job",
          "gridPos": { "h": 10, "w": 12, "x": 6, "y": 0 },
          "targets": [{ "expr": "sum by(job) (up)", "legendFormat": "{{job}}" }]
        },
        {
          "type": "table",
          "title": "Scrape Durations (p95)",
          "gridPos": { "h": 8, "w": 18, "x": 0, "y": 10 },
          "options": { "showHeader": true },
          "targets": [
            {
              "expr": "histogram_quantile(0.95, sum by(job, le) (rate(scrape_duration_seconds_bucket[5m])))",
              "legendFormat": "{{job}}"
            }
          ]
        }
      ]
    }
    EOT
  }
}
