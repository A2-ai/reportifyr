import os
import logging
from datetime import datetime


class RStyleFormatter(logging.Formatter):
    """Formatter matching R's log4r format: 2026-02-03 17:02:24 [INFO] message"""

    def format(self, record):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        return f"{timestamp} [{record.levelname}] {record.getMessage()}"


def setup_logger(log_file=None, console_level="WARN"):
    """
    Setup logger matching R's dual appender pattern.

    Args:
        log_file: Path to log file. If provided, DEBUG+ logs go to file.
        console_level: Minimum level for console output. Default WARN.
                      Respects RPFY_VERBOSE env var if set.

    Returns:
        Configured logger instance.
    """
    logger = logging.getLogger("rpfy")
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    # Check env var for console level override
    env_level = os.environ.get("RPFY_VERBOSE")
    if env_level:
        console_level = env_level

    # File handler - always DEBUG level
    if log_file:
        fh = logging.FileHandler(log_file, mode="a")
        fh.setLevel(logging.DEBUG)
        fh.setFormatter(RStyleFormatter())
        logger.addHandler(fh)

    # Console handler - filtered by console_level
    level_map = {
        "DEBUG": logging.DEBUG,
        "INFO": logging.INFO,
        "WARN": logging.WARNING,
        "WARNING": logging.WARNING,
        "ERROR": logging.ERROR,
    }
    ch = logging.StreamHandler()
    ch.setLevel(level_map.get(console_level.upper(), logging.WARNING))
    ch.setFormatter(RStyleFormatter())
    logger.addHandler(ch)

    return logger
