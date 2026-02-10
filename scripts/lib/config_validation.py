#!/usr/bin/env python3
"""
Configuration Validation Module

Validates configuration files against schemas to prevent runtime errors.
Provides clear error messages when configs are invalid.
"""

import json
import re
from pathlib import Path
from typing import Any, Optional
from dataclasses import dataclass


class ValidationError(Exception):
    """Raised when configuration validation fails."""
    pass


class ConfigValidator:
    """Base class for configuration validation."""
    
    @classmethod
    def validate(cls, data: dict) -> "ConfigValidator":
        """Validate and create instance from dictionary."""
        raise NotImplementedError
    
    @classmethod
    def from_file(cls, path: Path) -> "ConfigValidator":
        """Load and validate from JSON file."""
        with open(path) as f:
            data = json.load(f)
        return cls.validate(data)


@dataclass
class NudgeRulesConfig(ConfigValidator):
    """Validates proactive-intel nudge-rules.json configuration."""
    
    stale_thresholds_days: dict[str, int]
    travel_alert_days: list[int]
    birthday_alert_days: int
    quiet_hours: dict[str, int]
    max_nudges_per_day: int
    priority_weights: dict[str, int]
    min_strength_for_followup: float
    
    # Valid ranges
    VALID_ENTITY_TYPES = {'person', 'project', 'org', 'event'}
    VALID_PRIORITIES = {'birthday', 'travel_prep', 'follow_up', 'stale_project', 
                        'relationship_insight', 'opportunity'}
    
    @classmethod
    def validate(cls, data: dict) -> "NudgeRulesConfig":
        errors = []
        
        # Validate stale_thresholds_days
        stale = data.get('stale_thresholds_days', {})
        if not isinstance(stale, dict):
            errors.append("stale_thresholds_days must be an object")
        else:
            for key, value in stale.items():
                if key not in cls.VALID_ENTITY_TYPES:
                    errors.append(f"stale_thresholds_days: invalid entity type '{key}'")
                if not isinstance(value, int) or value < 1 or value > 365:
                    errors.append(f"stale_thresholds_days.{key}: must be integer 1-365")
        
        # Validate travel_alert_days
        travel = data.get('travel_alert_days', [])
        if not isinstance(travel, list):
            errors.append("travel_alert_days must be an array")
        else:
            for day in travel:
                if not isinstance(day, int) or day < 1 or day > 365:
                    errors.append(f"travel_alert_days: invalid value {day}")
        
        # Validate birthday_alert_days
        bday = data.get('birthday_alert_days', 7)
        if not isinstance(bday, int) or bday < 1 or bday > 90:
            errors.append("birthday_alert_days: must be integer 1-90")
        
        # Validate quiet_hours
        quiet = data.get('quiet_hours', {})
        if not isinstance(quiet, dict):
            errors.append("quiet_hours must be an object")
        else:
            for key in ['start', 'end']:
                if key not in quiet:
                    errors.append(f"quiet_hours.{key}: required")
                elif not isinstance(quiet[key], int) or quiet[key] < 0 or quiet[key] > 23:
                    errors.append(f"quiet_hours.{key}: must be integer 0-23")
        
        # Validate max_nudges_per_day
        max_nudges = data.get('max_nudges_per_day', 5)
        if not isinstance(max_nudges, int) or max_nudges < 1 or max_nudges > 100:
            errors.append("max_nudges_per_day: must be integer 1-100")
        
        # Validate priority_weights
        weights = data.get('priority_weights', {})
        if not isinstance(weights, dict):
            errors.append("priority_weights must be an object")
        else:
            for key, value in weights.items():
                if key not in cls.VALID_PRIORITIES:
                    errors.append(f"priority_weights: invalid priority '{key}'")
                if not isinstance(value, int) or value < 0 or value > 100:
                    errors.append(f"priority_weights.{key}: must be integer 0-100")
        
        # Validate min_strength_for_followup
        min_strength = data.get('min_strength_for_followup', 0.5)
        if not isinstance(min_strength, (int, float)) or min_strength < 0 or min_strength > 1:
            errors.append("min_strength_for_followup: must be number 0.0-1.0")
        
        if errors:
            raise ValidationError("Invalid nudge-rules.json:\n" + "\n".join(f"  - {e}" for e in errors))
        
        return cls(
            stale_thresholds_days=stale,
            travel_alert_days=travel,
            birthday_alert_days=bday,
            quiet_hours=quiet,
            max_nudges_per_day=max_nudges,
            priority_weights=weights,
            min_strength_for_followup=float(min_strength)
        )
    
    def to_dict(self) -> dict:
        """Convert back to dictionary."""
        return {
            'stale_thresholds_days': self.stale_thresholds_days,
            'travel_alert_days': self.travel_alert_days,
            'birthday_alert_days': self.birthday_alert_days,
            'quiet_hours': self.quiet_hours,
            'max_nudges_per_day': self.max_nudges_per_day,
            'priority_weights': self.priority_weights,
            'min_strength_for_followup': self.min_strength_for_followup
        }


@dataclass 
class MCPorterConfig(ConfigValidator):
    """Validates mcporter.json MCP configuration."""
    
    servers: list[dict]
    
    @classmethod
    def validate(cls, data: dict) -> "MCPorterConfig":
        errors = []
        
        servers = data.get('servers', [])
        if not isinstance(servers, list):
            errors.append("servers must be an array")
        else:
            for i, server in enumerate(servers):
                if not isinstance(server, dict):
                    errors.append(f"servers[{i}]: must be an object")
                    continue
                
                # Check required fields
                if 'name' not in server:
                    errors.append(f"servers[{i}]: missing 'name'")
                if 'transport' not in server:
                    errors.append(f"servers[{i}]: missing 'transport'")
                elif server.get('transport') not in ['stdio', 'http']:
                    errors.append(f"servers[{i}]: transport must be 'stdio' or 'http'")
                
                # Validate transport-specific fields
                if server.get('transport') == 'http':
                    if 'baseUrl' not in server:
                        errors.append(f"servers[{i}]: http transport requires 'baseUrl'")
                    elif not re.match(r'^https?://', server.get('baseUrl', '')):
                        errors.append(f"servers[{i}]: baseUrl must be HTTP(S) URL")
                
                elif server.get('transport') == 'stdio':
                    if 'command' not in server:
                        errors.append(f"servers[{i}]: stdio transport requires 'command'")
        
        if errors:
            raise ValidationError("Invalid mcporter.json:\n" + "\n".join(f"  - {e}" for e in errors))
        
        return cls(servers=servers)


@dataclass
class CronJobConfig(ConfigValidator):
    """Validates Mission Control cron job configuration."""
    
    id: str
    name: str
    prompt: str
    schedule: str
    schedule_human: str
    timezone: str
    enabled: bool
    
    # Valid cron patterns (simplified)
    CRON_PATTERN = re.compile(
        r'^([0-5]?\d|\*|\*/\d+|\d+-\d+|\d+,\d+)\s+'  # minute
        r'([01]?\d|2[0-3]|\*|\*/\d+|\d+-\d+|\d+,\d+)\s+'  # hour
        r'([1-9]|[12]\d|3[01]|\*|\*/\d+|\d+-\d+|\d+,\d+)\s+'  # day of month
        r'([1-9]|1[0-2]|\*|\*/\d+|\d+-\d+|\d+,\d+)\s+'  # month
        r'([0-6]|\*|\*/\d+|\d+-\d+|\d+,\d+)$'  # day of week
    )
    
    VALID_TIMEZONES = {
        'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles',
        'UTC', 'Europe/London', 'Europe/Paris', 'Asia/Tokyo'
    }
    
    @classmethod
    def validate(cls, data: dict) -> "CronJobConfig":
        errors = []
        
        # Required string fields
        for field in ['id', 'name', 'prompt', 'schedule', 'scheduleHuman', 'timezone']:
            if field not in data:
                errors.append(f"missing required field: {field}")
            elif not isinstance(data[field], str):
                errors.append(f"{field}: must be a string")
        
        # Validate cron schedule format
        schedule = data.get('schedule', '')
        if schedule and not cls.CRON_PATTERN.match(schedule):
            errors.append(f"schedule: invalid cron format '{schedule}'")
        
        # Validate timezone
        tz = data.get('timezone', '')
        if tz and tz not in cls.VALID_TIMEZONES:
            errors.append(f"timezone: '{tz}' not in common timezone list (may still be valid)")
        
        # Validate enabled field
        if 'enabled' in data and not isinstance(data['enabled'], bool):
            errors.append("enabled: must be a boolean")
        
        if errors:
            raise ValidationError("Invalid cron job config:\n" + "\n".join(f"  - {e}" for e in errors))
        
        return cls(
            id=data['id'],
            name=data['name'],
            prompt=data['prompt'],
            schedule=data['schedule'],
            schedule_human=data.get('scheduleHuman', data['schedule']),
            timezone=data['timezone'],
            enabled=data.get('enabled', True)
        )


# Convenience functions
def validate_nudge_rules(path: Path) -> NudgeRulesConfig:
    """Validate nudge-rules.json file."""
    return NudgeRulesConfig.from_file(path)


def validate_mcporter_config(path: Path) -> MCPorterConfig:
    """Validate mcporter.json file."""
    return MCPorterConfig.from_file(path)


def validate_cron_jobs(path: Path) -> list[CronJobConfig]:
    """Validate crons.json file."""
    with open(path) as f:
        data = json.load(f)
    
    if not isinstance(data, dict) or 'crons' not in data:
        raise ValidationError("crons.json must contain a 'crons' array")
    
    return [CronJobConfig.validate(cron) for cron in data['crons']]


# Health check function
def validate_all_configs(workspace: Path) -> dict[str, Any]:
    """Validate all known configuration files in the workspace.
    
    Returns a dictionary with validation results.
    """
    results = {
        'valid': [],
        'invalid': [],
        'missing': []
    }
    
    configs = [
        ('nudge-rules.json', workspace / 'skills/proactive-intel/config/nudge-rules.json', validate_nudge_rules),
        ('mcporter.json', workspace / 'config/mcporter.json', validate_mcporter_config),
        ('crons.json', workspace / 'data/crons.json', validate_cron_jobs),
    ]
    
    for name, path, validator in configs:
        if not path.exists():
            results['missing'].append(name)
            continue
        
        try:
            validator(path)
            results['valid'].append(name)
        except (ValidationError, json.JSONDecodeError) as e:
            results['invalid'].append({'name': name, 'error': str(e)})
    
    return results


if __name__ == "__main__":
    # Test validation on actual configs
    import sys
    
    workspace = Path(__file__).parent.parent.parent.parent
    results = validate_all_configs(workspace)
    
    print("Configuration Validation Results")
    print("=" * 40)
    print(f"✅ Valid: {', '.join(results['valid']) or 'None'}")
    print(f"❌ Invalid: {', '.join(i['name'] for i in results['invalid']) or 'None'}")
    print(f"⚠️  Missing: {', '.join(results['missing']) or 'None'}")
    
    if results['invalid']:
        print("\nErrors:")
        for item in results['invalid']:
            print(f"  {item['name']}: {item['error']}")
        sys.exit(1)
    
    sys.exit(0)
