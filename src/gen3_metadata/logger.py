import logging
import os
from datetime import datetime

def setup_logger(name="gen3_metadata", log_file_prefix="gen3_metadata", level=logging.INFO):
    """
    Sets up a logger that writes to a file in the ./logs/ directory.
    The log file name starts with the current datetime.

    Args:
        name (str): Name of the logger.
        log_file_prefix (str): Prefix for the log file name.
        level (int): Logging level.
    Returns:
        logging.Logger: Configured logger instance.
    """
    log_dir = "./logs"
    os.makedirs(log_dir, exist_ok=True)
    dt_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = f"{dt_str}_{log_file_prefix}.log"
    log_path = os.path.join(log_dir, log_file)

    logger = logging.getLogger(name)
    logger.setLevel(level)

    # Prevent adding multiple handlers if logger is called multiple times
    if not logger.handlers:
        file_handler = logging.FileHandler(log_path)
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(name)s - %(message)s')
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

    return logger

