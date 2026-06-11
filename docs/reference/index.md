# Package index

## All functions

- [`build_master_table()`](https://n0n3z.github.io/regionalclassification/reference/build_master_table.md)
  : Build the master classification table from all loaded data
- [`check_conversion_path()`](https://n0n3z.github.io/regionalclassification/reference/check_conversion_path.md)
  : Check if a simple (direct, unambiguous) conversion is possible
- [`CLASSIFICATION_NODES`](https://n0n3z.github.io/regionalclassification/reference/CLASSIFICATION_NODES.md)
  : Classification node registry
- [`classification_reference`](https://n0n3z.github.io/regionalclassification/reference/classification_reference.md)
  [`classification_conventions`](https://n0n3z.github.io/regionalclassification/reference/classification_reference.md)
  [`classification_identifiers`](https://n0n3z.github.io/regionalclassification/reference/classification_reference.md)
  : Classification identifier conventions
- [`clear_split_weights()`](https://n0n3z.github.io/regionalclassification/reference/clear_split_weights.md)
  : Clear all registered split weights
- [`convert_codes()`](https://n0n3z.github.io/regionalclassification/reference/convert_codes.md)
  : Convert codes from one classification to another
- [`convert_dataset()`](https://n0n3z.github.io/regionalclassification/reference/convert_dataset.md)
  : Convert a geographic code column in a dataset
- [`detect_classification()`](https://n0n3z.github.io/regionalclassification/reference/detect_classification.md)
  : Auto-detect geographic classification from a vector of codes
- [`diagnose_classification()`](https://n0n3z.github.io/regionalclassification/reference/diagnose_classification.md)
  : Diagnose geographic code coverage against a classification
- [`.extract_postal_map()`](https://n0n3z.github.io/regionalclassification/reference/dot-extract_postal_map.md)
  : Extract and standardise a postal code mapping table (internal)
- [`.get_prebuilt_dir()`](https://n0n3z.github.io/regionalclassification/reference/dot-get_prebuilt_dir.md)
  : Resolve the directory containing the pre-built RDS files
- [`fuzzy_match_names()`](https://n0n3z.github.io/regionalclassification/reference/fuzzy_match_names.md)
  : Match entity names to classification codes using fuzzy matching
- [`get_all_classification_nodes()`](https://n0n3z.github.io/regionalclassification/reference/get_all_classification_nodes.md)
  : Get all nodes in the conversion graph
- [`get_conversion_matrix()`](https://n0n3z.github.io/regionalclassification/reference/get_conversion_matrix.md)
  : Generate a full conversion feasibility matrix
- [`get_crosswalk()`](https://n0n3z.github.io/regionalclassification/reference/get_crosswalk.md)
  : Build a full correspondence table between two classifications
- [`get_label()`](https://n0n3z.github.io/regionalclassification/reference/get_label.md)
  : Get official names for classification codes
- [`get_split_weights()`](https://n0n3z.github.io/regionalclassification/reference/get_split_weights.md)
  : Retrieve registered split weights
- [`identify_from_names()`](https://n0n3z.github.io/regionalclassification/reference/identify_from_names.md)
  : Identify codes from names (convenience wrapper)
- [`is_nomenclature()`](https://n0n3z.github.io/regionalclassification/reference/is_nomenclature.md)
  : Test whether an object is a nomenclature
- [`is_perimeter_preserving()`](https://n0n3z.github.io/regionalclassification/reference/is_perimeter_preserving.md)
  : Test whether a conversion path is perimeter-preserving
- [`list_available_conversions()`](https://n0n3z.github.io/regionalclassification/reference/list_available_conversions.md)
  : List all available conversion paths
- [`list_nomenclatures()`](https://n0n3z.github.io/regionalclassification/reference/list_nomenclatures.md)
  : List available nomenclatures
- [`list_split_weights()`](https://n0n3z.github.io/regionalclassification/reference/list_split_weights.md)
  : List all registered split weights
- [`load_all_raw_data()`](https://n0n3z.github.io/regionalclassification/reference/load_all_raw_data.md)
  : Load all raw data files and return a named list of data.tables
- [`load_master_data()`](https://n0n3z.github.io/regionalclassification/reference/load_master_data.md)
  : Load the pre-built master table from bundled RDS files
- [`nom_system()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-accessors.md)
  [`nom_level()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-accessors.md)
  [`nom_version()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-accessors.md)
  : Nomenclature components
- [`nomenclature_children()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-aggregation.md)
  [`nomenclature_parents()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-aggregation.md)
  : Aggregation links between nomenclatures
- [`nomenclature_levels()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-discovery.md)
  [`nomenclature_versions()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-discovery.md)
  : Levels / versions available for a system
- [`nomenclature()`](https://n0n3z.github.io/regionalclassification/reference/nomenclature.md)
  : Create a classification nomenclature object
- [`print_conversion_check()`](https://n0n3z.github.io/regionalclassification/reference/print_conversion_check.md)
  : Print a human-readable conversion path check
- [`rc_arrondissements_2019`](https://n0n3z.github.io/regionalclassification/reference/rc_arrondissements_2019.md)
  : Sample arrondissements – NIS 2019
- [`rc_communes_2019`](https://n0n3z.github.io/regionalclassification/reference/rc_communes_2019.md)
  : Sample communes – NIS 2019
- [`rc_communes_2025`](https://n0n3z.github.io/regionalclassification/reference/rc_communes_2025.md)
  : Sample communes – NIS 2025
- [`rc_dirty_municipalities_2019`](https://n0n3z.github.io/regionalclassification/reference/rc_dirty_municipalities_2019.md)
  : Dirty communes dataset – NIS 2019 (with deliberate data-quality
  issues)
- [`rc_full_districts_2019`](https://n0n3z.github.io/regionalclassification/reference/rc_full_districts_2019.md)
  : Complete districts dataset – NIS 2019
- [`rc_full_municipalities_2019`](https://n0n3z.github.io/regionalclassification/reference/rc_full_municipalities_2019.md)
  : Complete communes dataset – NIS 2019
- [`rc_full_municipalities_2025`](https://n0n3z.github.io/regionalclassification/reference/rc_full_municipalities_2025.md)
  : Complete communes dataset – NIS 2025
- [`rc_full_nuts3_2021`](https://n0n3z.github.io/regionalclassification/reference/rc_full_nuts3_2021.md)
  : Complete NUTS3 dataset – 2021 classification
- [`rc_full_nuts3_2027`](https://n0n3z.github.io/regionalclassification/reference/rc_full_nuts3_2027.md)
  : Complete NUTS3 dataset – 2027 classification
- [`rc_full_postal`](https://n0n3z.github.io/regionalclassification/reference/rc_full_postal.md)
  : Complete postal codes dataset
- [`rc_full_regions_2019`](https://n0n3z.github.io/regionalclassification/reference/rc_full_regions_2019.md)
  : Complete regions dataset – NIS 2019
- [`rc_nuts3_2021`](https://n0n3z.github.io/regionalclassification/reference/rc_nuts3_2021.md)
  : Sample NUTS3 regions – 2021 classification
- [`rc_postal`](https://n0n3z.github.io/regionalclassification/reference/rc_postal.md)
  : Sample postal codes
- [`rebase_series()`](https://n0n3z.github.io/regionalclassification/reference/rebase_series.md)
  : Rebase a longitudinal dataset to a single classification version
- [`rebuild_master_data()`](https://n0n3z.github.io/regionalclassification/reference/rebuild_master_data.md)
  : Rebuild the master table from raw source files and save as RDS
- [`register_split_weights()`](https://n0n3z.github.io/regionalclassification/reference/register_split_weights.md)
  : Register split weights for an ambiguous conversion
- [`save_master_tables()`](https://n0n3z.github.io/regionalclassification/reference/save_master_tables.md)
  : Save master table and all auxiliary tables to processed directory
- [`split_ambiguous()`](https://n0n3z.github.io/regionalclassification/reference/split_ambiguous.md)
  : Handle M:N conversions on a dataset using weighted splits
- [`split_weights_template()`](https://n0n3z.github.io/regionalclassification/reference/split_weights_template.md)
  : Build a split weights template for an ambiguous conversion pair
- [`validate_codes()`](https://n0n3z.github.io/regionalclassification/reference/validate_codes.md)
  : Validate codes against a known classification
- [`visualize_classification_graph()`](https://n0n3z.github.io/regionalclassification/reference/visualize_classification_graph.md)
  : Visualize the classification relationship graph
- [`visualize_conversion_matrix()`](https://n0n3z.github.io/regionalclassification/reference/visualize_conversion_matrix.md)
  : Visualize the conversion feasibility matrix as a heatmap
- [`visualize_hierarchy()`](https://n0n3z.github.io/regionalclassification/reference/visualize_hierarchy.md)
  : Visualize the hierarchy of a specific classification
