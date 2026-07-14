# Suppress R CMD CHECK "no visible binding for global variable" NOTEs that arise
# from data.table's non-standard evaluation.  Column names used inside [...] are
# listed here so the static checker knows they are intentional.
utils::globalVariables(c(
  # md$crosswalks column names (03_convert.R, 09_query.R)
  "from_id", "to_id", "code_from", "code_to", "nature", "relation",
  # md$entities column names (00b_registry.R, 09_query.R)
  "classification_id",
  # list_available_conversions result column (03_convert.R)
  "perimeter_relation",
  # get_conversion_matrix / visualize helpers
  "is_simple", "status", "executable",
  # get_label / build_crosswalk_table helpers (09_query.R)
  "label", "weight", "w",
  # .normalize_conversion_result row-count helper (03_convert.R)
  ".n_to",
  # split_weights_template helpers (07_split_ambiguous.R)
  "value", "mass"
))
