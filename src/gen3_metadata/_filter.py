"""
Internal helper for filtering Gen3 records by data_release.

Public entry point: :func:`filter_records_by_data_release`.

This module is intentionally dependency-free (stdlib only) so it can be
unit-tested without any Gen3/HTTP machinery.
"""

import logging
from datetime import datetime

logger = logging.getLogger(__name__)


LATEST_SENTINEL = "latest"


def _parse_iso_date(value):
    """Return datetime parsed from an ISO 8601 string, or None if invalid."""
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _summarize_field(records, field):
    """
    Collect a short, human-friendly summary of the values of ``field`` across
    ``records``. Returns ``None`` if no record has the field.
    - one unique value  -> the value as a repr string
    - <= 5 unique values -> comma-joined repr
    - more              -> "{first!r}, ... ({n} unique)"
    """
    values = []
    seen = set()
    for rec in records:
        if field not in rec:
            continue
        v = rec[field]
        try:
            key = (type(v).__name__, v)
        except TypeError:
            key = (type(v).__name__, str(v))
        if key in seen:
            continue
        seen.add(key)
        values.append(v)
    if not values:
        return None
    if len(values) == 1:
        return repr(values[0])
    if len(values) <= 5:
        return ", ".join(repr(v) for v in values)
    return f"{values[0]!r}, ... ({len(values)} unique)"


def filter_records_by_data_release(records, data_release, node_name, log_fn=None):
    """
    Filter a list of record dicts by ``data_release``.

    Behavior
    --------
    - ``data_release is None`` → records returned unchanged (backwards
      compatible).
    - ``data_release == "latest"`` → inspect the ``data_release_date`` field
      across records:

      * If no record has a ``data_release_date`` key, return the records
        unchanged and log an info message.
      * Otherwise parse each ``data_release_date`` as ISO 8601, compute the
        max, log the selected value once, and return only records whose
        ``data_release_date`` equals the selected max.
      * Records with unparseable dates are dropped with a warning.

    - Any other string → match ``record["data_release"]`` exactly
      (case-sensitive). If no record has a ``data_release`` key, return
      unchanged and log. Records missing the field (when at least one record
      has it) are dropped with a debug-level count log.

    Parameters
    ----------
    records : list[dict]
        The list of records (typically the ``data`` array from a Gen3
        export response).
    data_release : str or None
        Filter value. See behavior above.
    node_name : str
        The name of the node being filtered. Used only for logging.
    log_fn : callable, optional
        Single-argument callable used to surface user-facing info-level
        messages (e.g. the selected ``data_release_date``). Defaults to
        ``logger.info``. Callers that also want messages on stdout should
        pass a closure that does both ``logger.info`` AND ``print``.
        ``fetch_all_metadata`` and ``Gen3MetadataParser.fetch_data`` do this.

    Returns
    -------
    tuple
        ``(filtered_records, keep_idx)`` where ``keep_idx`` is the list of
        indices in the original ``records`` that survived the filter. Callers
        can use ``keep_idx`` to subset parallel structures (e.g. a pandas
        DataFrame or pre-parsed R data.frame) without re-normalizing.
    """
    if log_fn is None:
        log_fn = logger.info

    if data_release is None:
        return list(records), list(range(len(records)))

    if not records:
        return [], []

    if data_release == LATEST_SENTINEL:
        return _filter_latest(records, node_name, log_fn)

    return _filter_exact(records, data_release, node_name, log_fn)


def _filter_exact(records, data_release, node_name, log_fn):
    """Filter on exact match against the top-level ``data_release`` field."""
    has_field = any("data_release" in rec for rec in records)
    if not has_field:
        log_fn(
            f"node '{node_name}': no 'data_release' field found on any record; "
            f"passing through unchanged (data_release={data_release!r})"
        )
        return list(records), list(range(len(records)))

    keep_idx = []
    filtered = []
    dropped_missing = 0
    for i, rec in enumerate(records):
        if "data_release" not in rec:
            dropped_missing += 1
            continue
        if rec["data_release"] == data_release:
            keep_idx.append(i)
            filtered.append(rec)

    date_summary = _summarize_field(filtered, "data_release_date")
    date_part = f" data_release_date={date_summary}" if date_summary else ""
    log_fn(
        f"node '{node_name}': selected data_release={data_release!r}"
        f"{date_part} ({len(filtered)}/{len(records)} records)"
    )
    if dropped_missing:
        logger.debug(
            f"node '{node_name}': dropped {dropped_missing} record(s) missing "
            f"'data_release' field while filtering for {data_release!r}"
        )

    return filtered, keep_idx


def _filter_latest(records, node_name, log_fn):
    """Pick the max ISO date in data_release_date and filter to that."""
    has_field = any("data_release_date" in rec for rec in records)
    if not has_field:
        log_fn(
            f"node '{node_name}': no 'data_release_date' field found on any record; "
            f"passing through unchanged (data_release='latest')"
        )
        return list(records), list(range(len(records)))

    # Parse dates per record. Index-aligned with records.
    parsed = []  # list of (i, raw_value, datetime_or_None)
    unparseable = []
    for i, rec in enumerate(records):
        raw = rec.get("data_release_date")
        if raw is None:
            parsed.append((i, None, None))
            continue
        dt = _parse_iso_date(raw)
        if dt is None:
            parsed.append((i, raw, None))
            unparseable.append(raw)
        else:
            parsed.append((i, raw, dt))

    if unparseable:
        logger.warning(
            f"node '{node_name}': skipping {len(unparseable)} record(s) with "
            f"unparseable data_release_date values (e.g. {unparseable[0]!r})"
        )

    parseable_dts = [p[2] for p in parsed if p[2] is not None]
    if not parseable_dts:
        log_fn(
            f"node '{node_name}': no parseable data_release_date values; "
            f"passing through unchanged"
        )
        return list(records), list(range(len(records)))

    max_dt = max(parseable_dts)
    # Use the raw string of the first record hitting max_dt as the canonical
    # log value, since equivalent ISO strings compare equal as datetimes.
    max_raw = next(raw for _, raw, dt in parsed if dt == max_dt)

    keep_idx = [i for (i, _, dt) in parsed if dt == max_dt]
    filtered = [records[i] for i in keep_idx]

    version_summary = _summarize_field(filtered, "data_release")
    version_part = f" data_release={version_summary}" if version_summary else ""
    log_fn(
        f"node '{node_name}': selected data_release_date={max_raw}"
        f"{version_part} ({len(filtered)}/{len(records)} records)"
    )

    return filtered, keep_idx
