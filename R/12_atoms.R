# ==============================================================================
# 12_atoms.R - Atom-based conversion engine (internal, docs/plans/engine-redesign.md)
# ==============================================================================
# Every unit of every classification is a union of atoms. A conversion A -> B is
# then one join: (a, b) are linked iff they share an atom. No path search, no
# materialised shortcut, cardinality computed from the data.
#
# Transition (steps 1-3 of the plan): the atom is the NIS BEFORE_2019 commune,
# the finest partition the package can build today (2019 and 2025 reforms only
# merge communes or move whole ones). The membership table is derived from the
# shipped crosswalks at load time and cached, so the snapshot and the output of
# load_master_data() are unchanged. It is the default engine since step 3; the
# former crosswalk engine stays reachable with options(nbbbenuts.engine = "crosswalks").
# Switching the atom to postal codes (once the postal -> BEFORE_2019 commune
# correspondence and the population by postal code are available) only changes
# .atom_membership().
# ==============================================================================

# Atom classification and the commune version each node is defined on.
.ATOM_ID <- "NIS_MUNICIPALITY_BEFORE_2019"

#' Commune classification a node is built on (its "base")
#' @noRd
.atom_base <- function(id) {
  n <- CLASSIFICATION_NODES[[id]]
  if (n$system == "NIS" && !is.na(n$version)) return(sprintf("NIS_MUNICIPALITY_%s", n$version))
  if (n$system == "NUTS" && identical(n$version, VER_NUTS_2027)) return(CLS_NIS_MUNICIPALITY_2025)
  CLS_NIS_MUNICIPALITY_2019   # NUTS 2021, LAU, NBB, POSTAL, countries
}

# Level rank: a conversion never goes from a coarser to a finer level
# (de-aggregation), exactly the set the crosswalk engine executes.
.ATOM_LEVEL_RANK <- c(postal = 0L, municipality = 1L, district = 2L,
                      province = 3L, region = 4L, country = 5L)

#' Is `from` -> `to` a conversion the package offers?
#'
#' Same set as the crosswalk engine: target level not finer than the source,
#' and no conversion towards the BEFORE_2019 communes from another node (2019 ->
#' BEFORE_2019 de-fusion, deliberately left out).
#' @noRd
.atom_pair_allowed <- function(from, to) {
  if (from == to) return(TRUE)
  rf <- .ATOM_LEVEL_RANK[[CLASSIFICATION_NODES[[from]]$level]]
  rt <- .ATOM_LEVEL_RANK[[CLASSIFICATION_NODES[[to]]$level]]
  rf <= rt && to != CLS_NIS_MUNICIPALITY_BEFORE_2019
}

# Cache of the membership table, keyed by the crosswalks it was derived from.
.atom_cache <- new.env(parent = emptyenv())

#' Membership table: data.table(classification, code, atom)
#'
#' Derived from md$crosswalks: atoms -> commune of each version (BEFORE_2019 ->
#' 2019, then 2019 -> 2025), commune -> unit of each node. Postal codes are finer
#' than the atom: a postal code gets every atom of its 2019 commune, which is
#' exact for every conversion FROM a postal code to a commune-based node.
#' @noRd
.atom_membership <- function(md) {
  key <- paste0("membership_", nrow(md$crosswalks), "_", nrow(md$entities))
  if (exists(key, envir = .atom_cache, inherits = FALSE)) return(get(key, envir = .atom_cache))

  xw <- md$crosswalks
  lk <- function(f, t) unique(xw[classification_from == f & classification_to == t &
                                   !is.na(code_to), .(code_from, code_to)])
  comp <- function(l1, l2) unique(merge(l1[, .(code_from, mid = code_to)],
                                        l2[, .(mid = code_from, code_to)],
                                        by = "mid", allow.cartesian = TRUE)[, .(code_from, code_to)])
  atoms <- md$entities[classification == .ATOM_ID, code]

  # atom -> commune of each version
  to_base <- list()
  to_base[[.ATOM_ID]] <- data.table(code_from = atoms, code_to = atoms)
  to_base[[CLS_NIS_MUNICIPALITY_2019]] <- lk(.ATOM_ID, CLS_NIS_MUNICIPALITY_2019)
  to_base[[CLS_NIS_MUNICIPALITY_2025]] <- comp(to_base[[CLS_NIS_MUNICIPALITY_2019]],
                                               lk(CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025))

  # commune -> unit of a node (direct crosswalk, else the engine on N:1 links)
  base_to_node <- function(base, id) {
    if (id == base) {
      codes <- md$entities[classification == base, code]
      return(data.table(code_from = codes, code_to = codes))
    }
    l <- lk(base, id)
    if (nrow(l) > 0L) return(l)
    codes <- md$entities[classification == base, code]
    old <- options(nbbbenuts.engine = "crosswalks"); on.exit(options(old), add = TRUE)
    r <- suppressWarnings(route_conversion(data.table(code_from = codes), base, id, md))
    unique(r[!is.na(code_to), .(code_from = as.character(code_from), code_to = as.character(code_to))])
  }

  parts <- lapply(setdiff(names(CLASSIFICATION_NODES), CLS_POSTAL), function(id) {
    base <- .atom_base(id)
    m <- comp(to_base[[base]], base_to_node(base, id))   # atom -> unit
    data.table(classification = id, code = m$code_to, atom = m$code_from)
  })
  # postal code -> every atom of its 2019 commune
  p <- lk(CLS_POSTAL, CLS_NIS_MUNICIPALITY_2019)
  a19 <- to_base[[CLS_NIS_MUNICIPALITY_2019]][, .(atom = code_from, mun = code_to)]
  pm <- unique(merge(p[, .(code = code_from, mun = code_to)], a19, by = "mun",
                     allow.cartesian = TRUE)[, .(classification = CLS_POSTAL, code, atom)])
  out <- unique(rbindlist(c(parts, list(pm)), use.names = TRUE))

  # Postal atoms: once the postal -> BEFORE_2019 commune correspondence is in the
  # crosswalks (one commune per postal code, hypothesis H2 of the design note),
  # the postal codes refine the BEFORE_2019 atoms: every unit becomes the set of
  # postal codes of its BEFORE_2019 communes, and a postal code is its own atom.
  pb <- lk(CLS_POSTAL, CLS_NIS_MUNICIPALITY_BEFORE_2019)
  if (nrow(pb) > 0L) {
    if (anyDuplicated(pb$code_from))
      abort("POSTAL -> NIS_MUNICIPALITY_BEFORE_2019 must give one commune per postal code.",
            class = "rcl_schema_error")
    refine <- pb[, .(atom = code_to, postal = code_from)]
    out <- unique(merge(out[classification != CLS_POSTAL], refine, by = "atom",
                        allow.cartesian = TRUE)[, .(classification, code, atom = postal)])
    out <- rbind(out, data.table(classification = CLS_POSTAL, code = refine$postal,
                                 atom = refine$postal))
  }
  setkey(out, classification, code)
  assign(key, out, envir = .atom_cache)
  out
}

#' Classification whose codes are the atoms of `md`
#' @noRd
.atom_id <- function(md) {
  pb <- md$crosswalks[classification_from == CLS_POSTAL &
                      classification_to == CLS_NIS_MUNICIPALITY_BEFORE_2019]
  if (nrow(pb) > 0L) CLS_POSTAL else .ATOM_ID
}

#' Convert codes through the atoms
#'
#' Returns data.table(code_from, code_to, nature) like route_conversion(): one
#' row per (input code, target), code_to = NA for an unknown source code.
#' `nature` follows the crosswalk engine during the transition: the crosswalk
#' rows' nature (normalised) when the pair is a stored hop, NA otherwise.
#' @noRd
.convert_via_atoms <- function(input_dt, from, to, md) {
  mem <- .atom_membership(md)
  src <- data.table(code_from = .node_coerce(input_dt$code_from, from), .ord = seq_len(nrow(input_dt)))
  links <- if (from == to) {
    u <- unique(mem[classification == from, code]); data.table(code_from = u, code_to = u)
  } else {
    unique(merge(mem[classification == from, .(code_from = code, atom)],
                 mem[classification == to,   .(code_to = code, atom)],
                 by = "atom", allow.cartesian = TRUE)[, .(code_from, code_to)])
  }
  res <- merge(src, links, by = "code_from", all.x = TRUE, allow.cartesian = TRUE, sort = FALSE)
  setorder(res, .ord)
  n_na <- res[is.na(code_to), uniqueN(.ord)]   # NA inputs count, as in the crosswalk engine
  if (n_na > 0L)
    warn(sprintf("%d code(s) could not be converted (no match found)", n_na),
         class = "rcl_unmatched_codes")
  res <- res[, .(code_from, code_to = .node_coerce(code_to, to))]

  direct <- md$crosswalks[classification_from == from & classification_to == to]
  if (from == to || nrow(direct) > 0L) {
    nat <- unique(direct[, .(code_from, code_to, nature)])
    res <- merge(res, nat, by = c("code_from", "code_to"), all.x = TRUE, sort = FALSE)
    return(.normalize_conversion_result(res, from, to))
  }
  res[, nature := NA_character_]
  .normalize_conversion_result(res)
}

#' Which engine executes conversions (internal switch)
#'
#' Default "atoms" since step 3 of the redesign; "crosswalks" (the former
#' path-composition engine) stays available as a fallback until step 5.
#' @noRd
.engine <- function() getOption("nbbbenuts.engine", "atoms")
