#!/usr/bin/env python3
"""
Structured Logging Module

Provides standardized, JSON-structured logging with correlation IDs,
performance metrics, and consistent schema across all OpenClaw components.

Usage:
    from structured_logging import get_logger
    
    logger = get_logger("pi-nudge-engine")
    logger.info("nudge_generated", data={"type": "follow_up", "priority": 7})
    
    # With timing
    with logger.timed("database_query"):
        result = db.query()
"""

import json
import uuid
import time
import os
from pathlib import Path
from datetime import datetime, timezone
from contextlib import contextmanager
from typing import Any, Optional
from dataclasses import dataclass, asdict
from functools import wraps


# Log file location
DEFAULT_LOG_FILE = Path(os.environ.get(
    "OPENCLAW_LOG_FILE",
    os.path.expanduser("~/.openclaw/workspace/logs/openclaw-events.jsonl"),
))

# Component name from environment or default
COMPONENT = os.environ.get("OPENCLAW_COMPONENT", "unknown")
CORRELATION_ID = os.environ.get("OPENCLAW_CORRELATION_ID") or str(uuid.uuid4())[:8]


@dataclass
class LogEntry:
    """Standardized log entry schema."""
    timestamp: str
    level: str
    component: str
    correlation_id: str
    event: str
    message: str
    data: Optional[dict] = None
    performance: Optional[dict] = None
    error: Optional[dict] = None
    
    def to_dict(self) -> dict:
        """Convert to dictionary, excluding None values."""
        result = asdict(self)
        return {k: v for k, v in result.items() if v is not None}


class StructuredLogger:
    """Logger with structured JSON output."""
    
    LEVELS = {"DEBUG": 10, "INFO": 20, "WARN": 30, "ERROR": 40, "FATAL": 50}
    
    def __init__(self, component: str, log_file: Path = DEFAULT_LOG_FILE, 
                 correlation_id: Optional[str] = None, min_level: str = "INFO"):
        self.component = component
        self.log_file = Path(log_file)
        self.correlation_id = correlation_id or CORRELATION_ID
        self.min_level = self.LEVELS.get(min_level, 20)
        
        # Ensure log directory exists
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
    
    def _log(self, level: str, event: str, message: str, 
             data: Optional[dict] = None,
             performance: Optional[dict] = None,
             error: Optional[dict] = None):
        """Write a log entry."""
        if self.LEVELS.get(level, 20) < self.min_level:
            return
        
        entry = LogEntry(
            timestamp=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
            level=level,
            component=self.component,
            correlation_id=self.correlation_id,
            event=event,
            message=message,
            data=data,
            performance=performance,
            error=error
        )
        
        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry.to_dict(), default=str) + "\n")
        except Exception:
            # Never let logging break the application
            pass
    
    def debug(self, event: str, message: str = "", data: Optional[dict] = None):
        """Log debug level."""
        self._log("DEBUG", event, message, data=data)
    
    def info(self, event: str, message: str = "", data: Optional[dict] = None):
        """Log info level."""
        self._log("INFO", event, message, data=data)
    
    def warn(self, event: str, message: str = "", data: Optional[dict] = None):
        """Log warning level."""
        self._log("WARN", event, message, data=data)
    
    def error(self, event: str, message: str = "", data: Optional[dict] = None,
              exception: Optional[Exception] = None):
        """Log error level."""
        error_info = None
        if exception:
            error_info = {
                "type": type(exception).__name__,
                "message": str(exception)
            }
        self._log("ERROR", event, message, data=data, error=error_info)
    
    def fatal(self, event: str, message: str = "", data: Optional[dict] = None,
              exception: Optional[Exception] = None):
        """Log fatal level."""
        error_info = None
        if exception:
            error_info = {
                "type": type(exception).__name__,
                "message": str(exception)
            }
        self._log("FATAL", event, message, data=data, error=error_info)
    
    @contextmanager
    def timed(self, event: str, message: str = "", data: Optional[dict] = None):
        """Context manager for timing operations."""
        start_time = time.time()
        start_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
        
        try:
            yield self
            duration_ms = (time.time() - start_time) * 1000
            
            perf_data = {
                "duration_ms": round(duration_ms, 2),
                "start_time": start_iso,
                "status": "success"
            }
            
            self._log("INFO", event, message, data=data, performance=perf_data)
            
        except Exception as e:
            duration_ms = (time.time() - start_time) * 1000
            
            perf_data = {
                "duration_ms": round(duration_ms, 2),
                "start_time": start_iso,
                "status": "error"
            }
            
            error_info = {
                "type": type(e).__name__,
                "message": str(e)
            }
            
            self._log("ERROR", event, message, data=data, performance=perf_data, error=error_info)
            raise
    
    def with_correlation_id(self, correlation_id: str) -> "StructuredLogger":
        """Create a new logger with a different correlation ID."""
        return StructuredLogger(
            component=self.component,
            log_file=self.log_file,
            correlation_id=correlation_id,
            min_level=[k for k, v in self.LEVELS.items() if v == self.min_level][0]
        )
    
    def with_component(self, component: str) -> "StructuredLogger":
        """Create a new logger with a different component name."""
        return StructuredLogger(
            component=component,
            log_file=self.log_file,
            correlation_id=self.correlation_id,
            min_level=[k for k, v in self.LEVELS.items() if v == self.min_level][0]
        )


# Global logger cache
_loggers: dict[str, StructuredLogger] = {}


def get_logger(component: str, log_file: Optional[Path] = None, 
               correlation_id: Optional[str] = None) -> StructuredLogger:
    """Get or create a logger for a component."""
    key = f"{component}:{correlation_id or CORRELATION_ID}"
    
    if key not in _loggers:
        _loggers[key] = StructuredLogger(
            component=component,
            log_file=log_file or DEFAULT_LOG_FILE,
            correlation_id=correlation_id
        )
    
    return _loggers[key]


def log_performance(component: str, event: str, duration_ms: float, 
                   data: Optional[dict] = None, success: bool = True):
    """Convenience function for logging performance metrics."""
    logger = get_logger(component)
    
    perf_data = {
        "duration_ms": round(duration_ms, 2),
        "status": "success" if success else "error"
    }
    
    level = "INFO" if success else "WARN"
    logger._log(level, event, f"{event} completed", data=data, performance=perf_data)


def configure_logging(log_file: Optional[Path] = None, min_level: str = "INFO"):
    """Configure global logging settings."""
    global DEFAULT_LOG_FILE
    if log_file:
        DEFAULT_LOG_FILE = Path(log_file)
    
    # Update all existing loggers
    for logger in _loggers.values():
        logger.log_file = DEFAULT_LOG_FILE
        logger.min_level = StructuredLogger.LEVELS.get(min_level, 20)


# Decorator for automatic timing
def timed(event: str, component: Optional[str] = None):
    """Decorator for timing function execution."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            comp = component or func.__module__
            logger = get_logger(comp)
            
            with logger.timed(event, data={"function": func.__name__}):
                return func(*args, **kwargs)
        
        return wrapper
    return decorator


# Backward compatibility with old logging
class LegacyLogAdapter:
    """Adapter to make new structured logging compatible with old log_event calls."""
    
    def __init__(self, component: str = "legacy"):
        self.logger = get_logger(component)
    
    def __call__(self, level: str, message: str, command: str = ""):
        """Compatible with old log_event(level, message, command) signature."""
        event = command or "legacy_log"
        
        level_map = {
            "debug": "DEBUG",
            "info": "INFO", 
            "warn": "WARN",
            "warning": "WARN",
            "error": "ERROR",
            "fatal": "FATAL"
        }
        
        structured_level = level_map.get(level.lower(), "INFO")
        getattr(self.logger, structured_level.lower())(event, message)


# Example usage and test
if __name__ == "__main__":
    import tempfile
    import os
    
    # Test with temporary log file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False) as f:
        test_log = Path(f.name)
    
    try:
        # Create logger
        logger = get_logger("test-component", log_file=test_log)
        
        # Test basic logging
        logger.info("test_event", "Test message", data={"key": "value"})
        logger.warn("test_warning", "Something might be wrong")
        logger.error("test_error", "Something went wrong", exception=ValueError("Test error"))
        
        # Test timing
        with logger.timed("test_operation"):
            time.sleep(0.01)
        
        # Test failed operation timing
        try:
            with logger.timed("failing_operation"):
                raise RuntimeError("Planned failure")
        except RuntimeError:
            pass
        
        # Read and verify logs
        with open(test_log) as f:
            logs = [json.loads(line) for line in f]
        
        print(f"Generated {len(logs)} log entries")
        
        # Verify structure
        for log in logs:
            assert "timestamp" in log, "Missing timestamp"
            assert "level" in log, "Missing level"
            assert "component" in log, "Missing component"
            assert "correlation_id" in log, "Missing correlation_id"
            assert "event" in log, "Missing event"
            assert "message" in log, "Missing message"
        
        # Check performance data
        timed_logs = [l for l in logs if l.get("performance")]
        assert len(timed_logs) >= 1, "Should have timed logs"
        
        success_log = [l for l in timed_logs if l["performance"]["status"] == "success"][0]
        assert "duration_ms" in success_log["performance"]
        assert success_log["performance"]["duration_ms"] >= 10  # At least 10ms
        
        error_log = [l for l in timed_logs if l["performance"]["status"] == "error"][0]
        assert "error" in error_log
        
        print("✅ All structured logging tests passed!")
        
    finally:
        os.unlink(test_log)
