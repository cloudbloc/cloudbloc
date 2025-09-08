terraform {
  backend "gcs" {
    prefix = "foundation/networks"
  }
}
