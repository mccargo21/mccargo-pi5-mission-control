#!/usr/bin/env python3
"""
Metrics Collection Module

Tracks performance metrics, counts, and rates across OpenClaw components.
Provides aggregation, querying, and reporting capabilities.

Usage:
    from metrics import MetricsCollector, get_collector
    
    collector = get_collector("pi-nudge-engine")
    
    # Record timing
    with collector.time("database_query"):
        result = db.query()
    
    # Record count
    collector.increment("nudges_generated", tags={"type": "follow_up"})
    
    # Record gauge
    collector.gauge("active_connections", 5)
    
    # Get report
    report = collector.get_report()
"""

import json
import time
import os
from pathlib import Path
from datetime import datetime, timezone, timedelta
from collections import defaultdict
from contextlib import contextmanager
from dataclasses import dataclass, field, asdict
from typing import Any, Optional
from threading import Lock
import statistics


# Metrics storage location
METRICS_DIR = Path(os.environ.get(
    "OPENCLAW_METRICS_DIR",
    os.path.expanduser("~/.openclaw/workspace/logs/metrics"),
))


@dataclass
class MetricValue:
    """Single metric data point."""
    timestamp: float
    value: float
    tags: dict[str, str] = field(default_factory=dict)


@dataclass 
class MetricSeries:
    """Time series of metric values."""
    name: str
    metric_type: str  # counter, gauge, timer, histogram
    values: list[MetricValue] = field(default_factory=list)
    
    def add(self, value: float, tags: Optional[dict] = None):
        """Add a new value to the series."""
        self.values.append(MetricValue(
            timestamp=time.time(),
            value=value,
            tags=tags or {}
        ))
        
        # Keep only last 10000 values to prevent memory bloat
        if len(self.values) > 10000:
            self.values = self.values[-10000:]
    
    def get_stats(self, window_seconds: Optional[int] = None) -> dict:
        """Calculate statistics for this metric."""
        values = self.values
        
        if window_seconds:
            cutoff = time.time() - window_seconds
            values = [v for v in values if v.timestamp >= cutoff]
        
        if not values:
            return {"count": 0}
        
        vals = [v.value for v in values]
        
        stats = {
            "count": len(vals),
            "sum": sum(vals),
            "min": min(vals),
            "max": max(vals),
            "mean": statistics.mean(vals),
        }
        
        if len(vals) > 1:
            stats["stdev"] = statistics.stdev(vals)
            stats["median"] = statistics.median(vals)
        
        # For timers, add percentiles
        if self.metric_type == "timer":
            sorted_vals = sorted(vals)
            stats["p50"] = sorted_vals[int(len(sorted_vals) * 0.5)]
            stats["p95"] = sorted_vals[int(len(sorted_vals) * 0.95)]
            stats["p99"] = sorted_vals[int(len(sorted_vals) * 0.99)]
        
        return stats


class MetricsCollector:
    """Collects and aggregates metrics for a component."""
    
    def __init__(self, component: str, metrics_dir: Path = METRICS_DIR):
        self.component = component
        self.metrics_dir = Path(metrics_dir)
        self.metrics_dir.mkdir(parents=True, exist_ok=True)
        
        self._metrics: dict[str, MetricSeries] = {}
        self._lock = Lock()
        
        # Daily aggregation file
        self._daily_file = self.metrics_dir / f"{component}-{datetime.now(timezone.utc).strftime('%Y%m%d')}.jsonl"
    
    def _get_series(self, name: str, metric_type: str) -> MetricSeries:
        """Get or create a metric series."""
        key = f"{metric_type}:{name}"
        
        if key not in self._metrics:
            self._metrics[key] = MetricSeries(name=name, metric_type=metric_type)
        
        return self._metrics[key]
    
    def increment(self, name: str, value: float = 1, tags: Optional[dict] = None):
        """Increment a counter metric."""
        with self._lock:
            series = self._get_series(name, "counter")
            series.add(value, tags)
            self._persist(name, "counter", value, tags)
    
    def gauge(self, name: str, value: float, tags: Optional[dict] = None):
        """Record a gauge metric (value at a point in time)."""
        with self._lock:
            series = self._get_series(name, "gauge")
            series.add(value, tags)
            self._persist(name, "gauge", value, tags)
    
    @contextmanager
    def time(self, name: str, tags: Optional[dict] = None):
        """Time an operation and record the duration."""
        start = time.time()
        try:
            yield self
        finally:
            duration = (time.time() - start) * 1000  # Convert to ms
            with self._lock:
                series = self._get_series(name, "timer")
                series.add(duration, tags)
                self._persist(name, "timer", duration, tags)
    
    def histogram(self, name: str, value: float, tags: Optional[dict] = None):
        """Record a value in a histogram."""
        with self._lock:
            series = self._get_series(name, "histogram")
            series.add(value, tags)
            self._persist(name, "histogram", value, tags)
    
    def _persist(self, name: str, metric_type: str, value: float, tags: Optional[dict]):
        """Persist metric to disk for long-term storage."""
        try:
            entry = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "component": self.component,
                "metric": name,
                "type": metric_type,
                "value": value,
                "tags": tags or {}
            }
            
            with open(self._daily_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception:
            # Never let metrics break the application
            pass
    
    def get_stats(self, name: str, metric_type: str, 
                  window_seconds: Optional[int] = None) -> dict:
        """Get statistics for a specific metric."""
        key = f"{metric_type}:{name}"
        
        with self._lock:
            if key not in self._metrics:
                return {"count": 0}
            
            return self._metrics[key].get_stats(window_seconds)
    
    def get_report(self, window_seconds: Optional[int] = 3600) -> dict:
        """Generate a comprehensive metrics report."""
        report = {
            "component": self.component,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "window_seconds": window_seconds,
            "metrics": {}
        }
        
        with self._lock:
            for key, series in self._metrics.items():
                stats = series.get_stats(window_seconds)
                if stats["count"] > 0:
                    report["metrics"][f"{series.metric_type}:{series.name}"] = stats
        
        return report
    
    def get_summary(self) -> dict:
        """Get a brief summary of recent activity."""
        summary = {
            "component": self.component,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "counters": {},
            "gauges": {},
            "timers": {}
        }
        
        with self._lock:
            for key, series in self._metrics.items():
                if series.metric_type == "counter":
                    stats = series.get_stats(window_seconds=3600)  # Last hour
                    if stats["count"] > 0:
                        summary["counters"][series.name] = {
                            "last_hour": stats["sum"],
                            "total": sum(v.value for v in series.values)
                        }
                
                elif series.metric_type == "gauge":
                    if series.values:
                        summary["gauges"][series.name] = series.values[-1].value
                
                elif series.metric_type == "timer":
                    stats = series.get_stats(window_seconds=3600)
                    if stats["count"] > 0:
                        summary["timers"][series.name] = {
                            "count": stats["count"],
                            "mean_ms": round(stats["mean"], 2),
                            "p95_ms": round(stats.get("p95", 0), 2)
                        }
        
        return summary
    
    def reset(self):
        """Clear all metrics (useful for testing)."""
        with self._lock:
            self._metrics.clear()


# Global collector cache
_collectors: dict[str, MetricsCollector] = {}


def get_collector(component: str, metrics_dir: Optional[Path] = None) -> MetricsCollector:
    """Get or create a metrics collector for a component."""
    if component not in _collectors:
        _collectors[component] = MetricsCollector(
            component=component,
            metrics_dir=metrics_dir or METRICS_DIR
        )
    return _collectors[component]


def get_all_summaries() -> dict[str, dict]:
    """Get summaries from all collectors."""
    return {name: collector.get_summary() for name, collector in _collectors.items()}


def generate_daily_report(output_file: Optional[Path] = None) -> Path:
    """Generate a daily aggregate report from all metric files."""
    today = datetime.now(timezone.utc).strftime('%Y%m%d')
    
    # Collect all metrics for today
    all_metrics = defaultdict(list)
    
    for metrics_file in METRICS_DIR.glob(f"*-{today}.jsonl"):
        with open(metrics_file) as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    key = f"{entry['component']}/{entry['metric']}"
                    all_metrics[key].append(entry)
                except (json.JSONDecodeError, KeyError):
                    continue
    
    # Generate report
    report = {
        "date": today,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "metrics": {}
    }
    
    for key, values in all_metrics.items():
        if not values:
            continue
        
        component, metric = key.split("/", 1)
        vals = [v["value"] for v in values]
        
        report["metrics"][key] = {
            "component": component,
            "metric": metric,
            "type": values[0]["type"],
            "count": len(vals),
            "sum": sum(vals),
            "mean": statistics.mean(vals) if len(vals) > 1 else vals[0],
            "min": min(vals),
            "max": max(vals)
        }
        
        if len(vals) > 1:
            report["metrics"][key]["stdev"] = statistics.stdev(vals)
    
    # Write report
    if output_file is None:
        output_file = METRICS_DIR / f"daily-report-{today}.json"
    
    with open(output_file, "w") as f:
        json.dump(report, f, indent=2)
    
    return output_file


# Convenience functions for common patterns
def record_nudge_generated(nudge_type: str, priority: int):
    """Record that a nudge was generated."""
    collector = get_collector("proactive-intel")
    collector.increment("nudges_generated", tags={"type": nudge_type, "priority": str(priority)})


def record_kg_query(operation: str, duration_ms: float, rows: int = 0):
    """Record a Knowledge Graph query."""
    collector = get_collector("knowledge-graph")
    collector.gauge("kg_query_rows", rows, tags={"operation": operation})
    with collector.time("kg_query_time", tags={"operation": operation}):
        pass  # Duration already measured


def record_task_extraction(source: str, success: bool, task_count: int = 0):
    """Record a task extraction event."""
    collector = get_collector("task-extractor")
    collector.increment("extractions", tags={"source": source, "success": str(success)})
    if success and task_count > 0:
        collector.gauge("tasks_extracted", task_count, tags={"source": source})


# Example usage and test
if __name__ == "__main__":
    import tempfile
    import shutil
    
    # Test with temporary directory
    test_dir = tempfile.mkdtemp()
    
    try:
        # Create collector
        collector = MetricsCollector("test-component", metrics_dir=Path(test_dir))
        
        # Test counter
        collector.increment("test_counter", 1, {"tag": "value"})
        collector.increment("test_counter", 2, {"tag": "value"})
        
        # Test gauge
        collector.gauge("test_gauge", 42.5)
        collector.gauge("test_gauge", 43.0)
        
        # Test timer
        with collector.time("test_operation"):
            time.sleep(0.01)
        
        with collector.time("test_operation"):
            time.sleep(0.02)
        
        # Get stats
        counter_stats = collector.get_stats("test_counter", "counter")
        assert counter_stats["count"] == 2, f"Expected count 2, got {counter_stats['count']}"
        assert counter_stats["sum"] == 3, f"Expected sum 3, got {counter_stats['sum']}"
        
        timer_stats = collector.get_stats("test_operation", "timer")
        assert timer_stats["count"] == 2, f"Expected count 2, got {timer_stats['count']}"
        assert timer_stats["mean"] >= 10, f"Expected mean >= 10ms, got {timer_stats['mean']}"
        assert "p95" in timer_stats, "Expected p95 in timer stats"
        
        # Get summary
        summary = collector.get_summary()
        assert "test_counter" in summary["counters"], "Missing counter in summary"
        assert "test_gauge" in summary["gauges"], "Missing gauge in summary"
        assert "test_operation" in summary["timers"], "Missing timer in summary"
        
        # Get report
        report = collector.get_report(window_seconds=3600)
        assert "metrics" in report, "Missing metrics in report"
        assert len(report["metrics"]) == 3, f"Expected 3 metrics, got {len(report['metrics'])}"
        
        print("✅ All metrics tests passed!")
        print(f"\nSummary: {json.dumps(summary, indent=2)}")
        
    finally:
        shutil.rmtree(test_dir)
