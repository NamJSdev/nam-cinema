import json
import logging
import sys
from datetime import datetime, timezone
from typing import Any


class StructuredJsonFormatter(logging.Formatter):
    """Formats logs as structured JSON while redacting sensitive tokens."""

    REDACTED_KEYS = {
        "password",
        "access_token",
        "refresh_token",
        "token",
        "authorization",
        "playback_token",
        "signature",
        "secret",
    }

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "extra_data") and isinstance(record.extra_data, dict):
            sanitized = {
                k: ("***REDACTED***" if k.lower() in self.REDACTED_KEYS else v)
                for k, v in record.extra_data.items()
            }
            payload["context"] = sanitized
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def configure_logging(debug: bool = False) -> None:
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG if debug else logging.INFO)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(StructuredJsonFormatter())
    root_logger.handlers = [handler]
