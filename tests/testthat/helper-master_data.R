master_data <- load_master_data()

# Wide tables of nbbbenuts 2.x, rebuilt from the long model (v3.0.0).
wide_md <- list(
  municipalities = wide_view(master_data, "municipalities"),
  postal         = wide_view(master_data, "postal"),
  nis_changes    = wide_view(master_data, "nis_changes")
)
