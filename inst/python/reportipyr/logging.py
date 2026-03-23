import sys
import logging
from datetime import datetime


class RStyleFormatter(logging.Formatter):
    """Formatter matching R's log4r format with [py] source tag."""

    def format(self, record):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        return f"{timestamp} [py] [{record.levelname}] {record.getMessage()}"


def setup_logger():
    """
    Setup logger that writes all levels to stderr.
    R captures stderr via callback and handles verbosity filtering
    for console display. Log file always gets everything.

    Returns:
        Configured logger instance.
    """
    logger = logging.getLogger("rpfy")
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    ch = logging.StreamHandler(sys.stderr)
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(RStyleFormatter())
    logger.addHandler(ch)

    return logger
