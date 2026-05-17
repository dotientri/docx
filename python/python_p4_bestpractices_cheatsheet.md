# 🐍 PYTHON TOÀN TẬP - PHẦN 4: BEST PRACTICES & CHEAT SHEET

---

## 1. Type Hints & Pydantic

### 1.1 Type Annotations
```python
from typing import Optional, List, Dict, Tuple, Union, Any, Callable
from typing import TypeVar, Generic
from collections.abc import Iterator, Generator

# Function signatures
def deploy_service(
    name: str,
    image: str,
    replicas: int = 1,
    environment: Optional[Dict[str, str]] = None,
    tags: List[str] | None = None,        # Python 3.10+ union syntax
) -> Dict[str, Any]:
    ...

# TypeVar for generics
T = TypeVar("T")

def first_or_default(items: List[T], default: T) -> T:
    return items[0] if items else default

# Generic class
class Repository(Generic[T]):
    def __init__(self):
        self._items: List[T] = []
    
    def add(self, item: T) -> None:
        self._items.append(item)
    
    def get_all(self) -> List[T]:
        return self._items.copy()
```

### 1.2 Pydantic (Data Validation)
```python
from pydantic import BaseModel, Field, validator, field_validator
from typing import Optional, List
from enum import Enum

class Environment(str, Enum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"

class DatabaseConfig(BaseModel):
    host: str = Field(..., description="Database host")
    port: int = Field(default=5432, ge=1024, le=65535)
    database: str
    username: str
    password: str = Field(..., min_length=8)
    ssl_mode: str = "require"
    pool_size: int = Field(default=10, ge=1, le=100)

    class Config:
        env_prefix = "DB_"   # Load from DB_HOST, DB_PORT, etc.

class AppConfig(BaseModel):
    app_name: str
    version: str = "1.0.0"
    environment: Environment
    debug: bool = False
    database: DatabaseConfig
    allowed_hosts: List[str] = ["*"]
    
    @field_validator("version")
    @classmethod
    def validate_semver(cls, v: str) -> str:
        import re
        if not re.match(r"^\d+\.\d+\.\d+$", v):
            raise ValueError("Version must be in semver format (x.y.z)")
        return v

# Load from dict (e.g., JSON config file)
config = AppConfig(
    app_name="myapi",
    version="1.2.3",
    environment=Environment.PRODUCTION,
    database=DatabaseConfig(
        host="postgres.prod.internal",
        database="myappdb",
        username="apiuser",
        password="supersecurepassword"
    )
)
print(config.model_dump_json(indent=2))

# Load from environment variables
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    azure_client_id: str = ""
    max_workers: int = 4
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
```

---

## 2. Logging Best Practices

```python
import logging
import sys
import json
from datetime import datetime, timezone

# Structured JSON logging (for log aggregation systems)
class JSONFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_obj = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        if record.exc_info:
            log_obj["exception"] = self.formatException(record.exc_info)
        if hasattr(record, "extra"):
            log_obj.update(record.extra)
        return json.dumps(log_obj)

def setup_logging(level: str = "INFO", json_output: bool = False) -> logging.Logger:
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper()))
    
    handler = logging.StreamHandler(sys.stdout)
    if json_output:
        handler.setFormatter(JSONFormatter())
    else:
        handler.setFormatter(logging.Formatter(
            "%(asctime)s [%(levelname)s] %(name)s - %(message)s"
        ))
    root.addHandler(handler)
    return root

logger = setup_logging(level="INFO", json_output=True)

# Usage with context
logger.info("Deployment started", extra={"service": "api", "version": "1.2.0"})
logger.error("Pod failed", extra={"pod": "api-pod-abc", "namespace": "production"})
```

---

## 3. Configuration Patterns

```python
import os
from functools import lru_cache

# Pattern: Singleton config loaded once
class Config:
    _instance: "Config | None" = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._load()
        return cls._instance
    
    def _load(self):
        self.env = os.getenv("APP_ENV", "development")
        self.debug = os.getenv("DEBUG", "false").lower() == "true"
        self.db_url = os.getenv("DATABASE_URL", "postgresql://localhost/dev")
        self.redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
        self.azure_keyvault = os.getenv("AZURE_KEYVAULT_NAME", "")

# Singleton usage
config = Config()
print(config.env)   # "production"

# Or using lru_cache
@lru_cache(maxsize=1)
def get_config():
    from myapp.settings import Settings
    return Settings()

config = get_config()  # Loaded once, cached
```

---

## 4. Python Cheat Sheet DevOps

```python
# ===== STRING OPERATIONS =====
f"Hello {name}!"                    # f-string
f"{value:.2f}"                      # Format float 2 decimals
f"{number:,}"                       # 1,000,000 format
"".join(["a", "b", "c"])           # "abc"
"hello world".split()               # ["hello", "world"]
text.strip().lower().replace("-","_")

# ===== LIST OPERATIONS =====
nums = [1, 2, 3, 4, 5]
evens = [n for n in nums if n % 2 == 0]   # [2, 4]
doubled = list(map(lambda n: n*2, nums))   # [2,4,6,8,10]
total = sum(nums)                          # 15
maximum = max(nums)                        # 5
sorted_desc = sorted(nums, reverse=True)   # [5,4,3,2,1]
flat = [x for sub in [[1,2],[3,4]] for x in sub]  # [1,2,3,4]

# ===== DICT OPERATIONS =====
d = {"a": 1, "b": 2}
d.get("c", 0)                   # 0 (default)
{**d, "c": 3}                   # Merge dicts
{k: v for k, v in d.items() if v > 1}  # Filter
keys = list(d.keys())
vals = list(d.values())

# ===== FILE OPERATIONS =====
from pathlib import Path
p = Path("config.json")
p.exists()
p.read_text()
p.write_text("content")
list(Path(".").glob("*.py"))
p.parent / "subdir" / "file.txt"

# ===== SUBPROCESS =====
import subprocess
result = subprocess.run(["ls", "-la"], capture_output=True, text=True, check=True)
output = result.stdout
subprocess.run("cmd | grep pattern", shell=True, check=True)

# ===== JSON & YAML =====
import json
data = json.loads('{"key": "value"}')
text = json.dumps(data, indent=2)

import yaml
data = yaml.safe_load(open("config.yaml"))
yaml.dump(data, open("output.yaml", "w"))

# ===== ENVIRONMENT VARIABLES =====
import os
os.environ.get("DATABASE_URL", "default")
os.getenv("SECRET_KEY")         # None if not set
os.environ["NEW_VAR"] = "value" # Set

# ===== REGEX =====
import re
match = re.search(r"(\d+\.\d+\.\d+)", "version: 1.2.3")
if match:
    version = match.group(1)   # "1.2.3"
re.findall(r"\d+", "pod-123-abc-456")  # ["123", "456"]
re.sub(r"\s+", "-", "hello   world")   # "hello-world"

# ===== DATETIME =====
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc)
yesterday = now - timedelta(days=1)
formatted = now.strftime("%Y-%m-%d %H:%M:%S")
parsed = datetime.fromisoformat("2024-01-01T00:00:00+00:00")

# ===== CONTEXT MANAGERS =====
with open("file.txt") as f:         # Auto close
    content = f.read()

from contextlib import suppress
with suppress(FileNotFoundError):   # Ignore specific exception
    os.remove("maybe_exists.txt")

# ===== CONCURRENT EXECUTION =====
from concurrent.futures import ThreadPoolExecutor, as_completed

with ThreadPoolExecutor(max_workers=10) as executor:
    futures = {executor.submit(check_health, url): url for url in urls}
    for future in as_completed(futures):
        url = futures[future]
        try:
            result = future.result()
        except Exception as e:
            print(f"Error checking {url}: {e}")

# ===== GENERATORS =====
def read_large_file(filepath):
    """Read large file line by line without loading all into memory."""
    with open(filepath) as f:
        for line in f:
            yield line.strip()

for line in read_large_file("/var/log/huge.log"):
    if "ERROR" in line:
        print(line)
```

---

## 5. Python Best Practices cho DevOps

| Practice | Reason |
|----------|--------|
| Always use **virtual environments** (`python -m venv`) | Avoid dependency conflicts |
| **Pin dependency versions** (`requirements.txt` với `pip freeze`) | Reproducible builds |
| Use **`pathlib.Path`** thay vì `os.path` | Modern, cross-platform |
| Use **`subprocess.run`** với `check=True` | Fail fast on command errors |
| Never `import *` | Explicit imports, avoid namespace pollution |
| Use **type hints** everywhere | Better IDE support, catch bugs early |
| **Log, don't print** (dùng `logging` module) | Structured, configurable output |
| Use **`.env` files** + `python-dotenv` cho local dev | Security |
| Write **tests** với pytest | Confidence in changes |
| **`black` + `ruff`** cho formatting/linting | Consistent code style |

```bash
# Dev tools setup
pip install black ruff mypy pytest pytest-cov pre-commit

# .pre-commit-config.yaml
repos:
  - repo: https://github.com/psf/black
    rev: 24.3.0
    hooks:
      - id: black
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.3.0
    hooks:
      - id: ruff
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.9.0
    hooks:
      - id: mypy
```
