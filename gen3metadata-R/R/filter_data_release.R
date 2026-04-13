#' Filter a list of Gen3 records by data_release
#'
#' Internal helper mirroring the Python \code{filter_records_by_data_release}
#' implementation. Operates on a list of records (the
#' \code{jsonlite::fromJSON(..., simplifyVector = FALSE)$data} form).
#'
#' Behavior:
#' \itemize{
#'   \item \code{data_release} is \code{NULL} -> records returned unchanged.
#'   \item \code{data_release == "latest"} -> inspect \code{data_release_date}
#'     (ISO 8601 strings). If no record has the field, pass through with a
#'     \code{message()}. Otherwise parse each, pick the max, emit one
#'     \code{message()} naming the selected date, and return only records at
#'     that date. Unparseable dates are dropped with a \code{warning()}.
#'   \item Any other string -> exact, case-sensitive match against the
#'     top-level \code{data_release} field. If no record has the field,
#'     pass through with a \code{message()}. Records missing the field when
#'     others have it are dropped silently.
#' }
#'
#' Returns a list with two elements:
#' \itemize{
#'   \item \code{records}: the filtered list of records.
#'   \item \code{keep_idx}: integer vector of positions in the original list
#'     that survived the filter. Use this to subset a parallel structure
#'     (e.g. a pre-parsed data.frame) without re-serializing JSON.
#' }
#'
#' Logging convention: \code{message()} for info-level notices, \code{warning()}
#' only for recoverable anomalies (e.g. unparseable dates). Tests use
#' \code{expect_message()} / \code{suppressMessages()}.
#'
#' @param records A list of records (each element is itself a named list).
#' @param data_release Filter value: \code{NULL}, \code{"latest"}, or a string.
#' @param node_name Character string used in log messages.
#'
#' @return A list \code{list(records = ..., keep_idx = ...)}.
#'
#' @keywords internal
#' @noRd
filter_records_by_data_release <- function(records, data_release, node_name) {

    if (is.null(data_release)) {
        return(list(records = records, keep_idx = seq_along(records)))
    }

    if (length(records) == 0) {
        return(list(records = list(), keep_idx = integer(0)))
    }

    if (identical(data_release, "latest")) {
        return(.filter_latest(records, node_name))
    }

    .filter_exact(records, data_release, node_name)
}


#' Exact match on top-level data_release field.
#' @keywords internal
#' @noRd
.filter_exact <- function(records, data_release, node_name) {

    has_field <- any(vapply(records,
                            function(r) "data_release" %in% names(r),
                            logical(1)))
    if (!has_field) {
        message(sprintf(
            "node '%s': no 'data_release' field found on any record; passing through unchanged (data_release=%s)",
            node_name, shQuote(data_release)
        ))
        return(list(records = records, keep_idx = seq_along(records)))
    }

    keep_idx <- integer(0)
    for (i in seq_along(records)) {
        rec <- records[[i]]
        val <- rec[["data_release"]]
        if (is.null(val)) next
        if (identical(as.character(val), as.character(data_release))) {
            keep_idx <- c(keep_idx, i)
        }
    }

    filtered <- records[keep_idx]
    date_summary <- .summarize_field(filtered, "data_release_date")
    date_part <- if (!is.null(date_summary)) sprintf(" data_release_date=%s", date_summary) else ""
    message(sprintf(
        "node '%s': selected data_release=%s%s (%d/%d records)",
        node_name, shQuote(data_release), date_part, length(filtered), length(records)
    ))

    list(records = filtered, keep_idx = keep_idx)
}


#' Select latest ISO date in data_release_date.
#' @keywords internal
#' @noRd
.filter_latest <- function(records, node_name) {

    has_field <- any(vapply(records,
                            function(r) "data_release_date" %in% names(r),
                            logical(1)))
    if (!has_field) {
        message(sprintf(
            "node '%s': no 'data_release_date' field found on any record; passing through unchanged (data_release='latest')",
            node_name
        ))
        return(list(records = records, keep_idx = seq_along(records)))
    }

    raw <- vapply(records, function(r) {
        v <- r[["data_release_date"]]
        if (is.null(v)) NA_character_ else as.character(v)
    }, character(1))

    parsed <- suppressWarnings(as.Date(raw, format = "%Y-%m-%d"))
    # Also try ISO datetime form if date-only parse failed
    iso_attempt <- suppressWarnings(as.Date(raw))
    parsed[is.na(parsed) & !is.na(iso_attempt)] <- iso_attempt[is.na(parsed) & !is.na(iso_attempt)]

    unparseable <- !is.na(raw) & is.na(parsed)
    if (any(unparseable)) {
        warning(sprintf(
            "node '%s': skipping %d record(s) with unparseable data_release_date values (e.g. %s)",
            node_name, sum(unparseable), shQuote(raw[which(unparseable)[1]])
        ))
    }

    if (all(is.na(parsed))) {
        message(sprintf(
            "node '%s': no parseable data_release_date values; passing through unchanged",
            node_name
        ))
        return(list(records = records, keep_idx = seq_along(records)))
    }

    max_dt <- max(parsed, na.rm = TRUE)
    max_idx_first <- which(parsed == max_dt)[1]
    max_raw <- raw[max_idx_first]

    keep_idx <- which(!is.na(parsed) & parsed == max_dt)
    filtered <- records[keep_idx]

    version_summary <- .summarize_field(filtered, "data_release")
    version_part <- if (!is.null(version_summary)) sprintf(" data_release=%s", version_summary) else ""
    message(sprintf(
        "node '%s': selected data_release_date=%s%s (%d/%d records)",
        node_name, max_raw, version_part, length(filtered), length(records)
    ))

    list(records = filtered, keep_idx = keep_idx)
}


#' Summarize the unique values of a field across records.
#' Returns NULL if no record has the field; a single quoted string if 1 value;
#' comma-joined if <=5; or "'v1', ... (N unique)" otherwise.
#' @keywords internal
#' @noRd
.summarize_field <- function(records, field) {
    vals <- list()
    seen <- character(0)
    for (rec in records) {
        if (!(field %in% names(rec))) next
        v <- rec[[field]]
        if (is.null(v)) next
        key <- as.character(v)
        if (key %in% seen) next
        seen <- c(seen, key)
        vals[[length(vals) + 1]] <- v
    }
    n <- length(vals)
    if (n == 0) return(NULL)
    if (n == 1) return(shQuote(as.character(vals[[1]])))
    if (n <= 5) {
        return(paste(vapply(vals, function(v) shQuote(as.character(v)), character(1)),
                     collapse = ", "))
    }
    sprintf("%s, ... (%d unique)", shQuote(as.character(vals[[1]])), n)
}
