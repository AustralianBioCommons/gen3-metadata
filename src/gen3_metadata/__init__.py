import logging

from .gen3_metadata_parser import *
from ._filter import *

logging.getLogger(__name__).addHandler(logging.NullHandler())


def configure_logging(level=logging.INFO):
    """Attach a stderr StreamHandler to the gen3_metadata logger.

    Call this once in a REPL or notebook to see INFO/DEBUG output from
    gen3_metadata modules. Idempotent — does nothing if a StreamHandler
    is already attached.
    """
    pkg_logger = logging.getLogger(__name__)
    pkg_logger.setLevel(level)
    for h in pkg_logger.handlers:
        if isinstance(h, logging.StreamHandler) and not isinstance(h, logging.NullHandler):
            return pkg_logger
    handler = logging.StreamHandler()
    handler.setFormatter(
        logging.Formatter("%(asctime)s - %(levelname)s - %(name)s - %(message)s")
    )
    pkg_logger.addHandler(handler)
    return pkg_logger
