import os
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
    Setup logger that writes to stderr, filtered by RPFY_VERBOSE env var.
    R captures stderr via callback and passes lines through to console
    and log file.

    Returns:
        Configured logger instance.
    """
    logger = logging.getLogger("rpfy")
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    level_map = {
        "DEBUG": logging.DEBUG,
        "INFO": logging.INFO,
        "WARN": logging.WARNING,
        "WARNING": logging.WARNING,
        "ERROR": logging.ERROR,
        "FATAL": logging.CRITICAL,
    }

    console_level = os.environ.get("RPFY_VERBOSE", "WARN")

    ch = logging.StreamHandler(sys.stderr)
    ch.setLevel(level_map.get(console_level.upper(), logging.WARNING))
    ch.setFormatter(RStyleFormatter())
    logger.addHandler(ch)

    return logger
