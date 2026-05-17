# 🐍 PYTHON TOÀN TẬP - PHẦN 1: FUNDAMENTALS

---

## 1. Python Basics cho DevOps

### 1.1 Tại Sao Python cho DevOps?
- **Scripting**: Automation, data processing
- **SDK**: Azure SDK (`azure-sdk-for-python`), AWS boto3, GCP client libs
- **Tools**: Ansible viết bằng Python, nhiều DevOps tools dùng Python
- **Simplicity**: Readable, ít boilerplate hơn Java/Go

### 1.2 Python Environment Setup
```bash
# Dùng pyenv để quản lý Python versions
curl https://pyenv.run | bash

pyenv install 3.12.0
pyenv global 3.12.0

# Virtual environment (LUÔN dùng venv)
python3 -m venv .venv
source .venv/bin/activate        # Linux/Mac
.venv\Scripts\activate           # Windows

pip install -r requirements.txt
pip freeze > requirements.txt

# Hoặc dùng poetry (modern)
pip install poetry
poetry new myproject
poetry add requests azure-mgmt-resource
poetry shell
```

---

## 2. Data Types & Control Flow

### 2.1 Built-in Types
```python
# Strings
name = "DevOps Engineer"
path = f"/home/{name}/config"       # f-string
multi = """
Line 1
Line 2
"""

# String methods thường dùng
"hello world".upper()                # "HELLO WORLD"
"  spaces  ".strip()                 # "spaces"
"a,b,c".split(",")                   # ["a", "b", "c"]
",".join(["a", "b", "c"])           # "a,b,c"
"hello".replace("l", "r")           # "herro"
"error" in "this is an error"        # True

# Numbers
x = 10
y = 3
print(x // y)    # Integer division: 3
print(x % y)     # Modulo: 1
print(x ** y)    # Power: 1000
print(x / y)     # Float division: 3.333...

# Boolean
is_running = True
is_failed = not is_running   # False
result = is_running and not is_failed   # True
```

### 2.2 Lists, Tuples, Dicts, Sets
```python
# List (mutable, ordered)
pods = ["pod-a", "pod-b", "pod-c"]
pods.append("pod-d")
pods.remove("pod-a")
pods[0]           # "pod-b" (sau remove)
pods[-1]          # "pod-d" (last element)
pods[1:3]         # ["pod-c", "pod-d"] (slicing)
len(pods)         # 3
sorted(pods)      # Sorted copy

# Tuple (immutable, ordered)
coordinates = (10.5, 20.3)
lat, lon = coordinates   # Unpacking

# Dict (key-value, ordered in 3.7+)
config = {
    "host": "localhost",
    "port": 5432,
    "database": "mydb"
}
config["host"]                      # "localhost"
config.get("timeout", 30)          # Default value nếu key không tồn tại
config["ssl"] = True               # Add key
del config["ssl"]                  # Remove key
config.keys()                      # dict_keys(["host", "port", "database"])
config.values()                    # dict_values(...)
config.items()                     # Trả về (key, value) pairs

# Set (unique values, unordered)
failed_pods = {"pod-a", "pod-b"}
running_pods = {"pod-b", "pod-c", "pod-d"}
both_sets = failed_pods | running_pods   # Union
only_failed = failed_pods - running_pods # Difference
```

### 2.3 List Comprehension
```python
# Tạo danh sách từ iterable (ngắn gọn, nhanh)
pods = ["pod-a", "pod-b", "pod-c"]

# Standard
upper_pods = [p.upper() for p in pods]
# ["POD-A", "POD-B", "POD-C"]

# Với điều kiện
long_names = [p for p in pods if len(p) > 5]

# Dict comprehension
pod_status = {pod: "running" for pod in pods}
# {"pod-a": "running", "pod-b": "running", "pod-c": "running"}

# Generator (lazy evaluation, tiết kiệm memory)
cpu_gen = (get_cpu(pod) for pod in pods)  # Chưa chạy
for cpu in cpu_gen:                        # Chạy từng cái
    print(cpu)
```

---

## 3. Functions

### 3.1 Function Definitions
```python
# Basic function
def greet(name: str, greeting: str = "Hello") -> str:
    return f"{greeting}, {name}!"

print(greet("DevOps"))          # "Hello, DevOps!"
print(greet("Team", "Hi"))      # "Hi, Team!"

# *args và **kwargs
def deploy(*services, **options):
    """Deploy multiple services with options."""
    print(f"Deploying: {services}")
    print(f"Options: {options}")

deploy("api", "worker", "scheduler", 
       namespace="production", timeout=300)
# Deploying: ('api', 'worker', 'scheduler')
# Options: {'namespace': 'production', 'timeout': 300}

# Lambda (anonymous function)
get_tag = lambda d, k: d.get(k, "unknown")
print(get_tag({"env": "prod"}, "env"))  # "prod"
```

### 3.2 Decorators (Quan Trọng!)
```python
import time
import functools

# Decorator đơn giản
def timer(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"{func.__name__} took {elapsed:.3f}s")
        return result
    return wrapper

@timer
def slow_operation():
    time.sleep(1)
    return "done"

slow_operation()  # "slow_operation took 1.001s"

# Decorator với arguments
def retry(max_attempts=3, delay=1.0):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_attempts - 1:
                        raise
                    print(f"Attempt {attempt+1} failed: {e}. Retrying...")
                    time.sleep(delay)
        return wrapper
    return decorator

@retry(max_attempts=3, delay=2.0)
def unstable_api_call():
    # Có thể fail
    import random
    if random.random() < 0.7:
        raise ConnectionError("API timeout")
    return "success"
```

---

## 4. Error Handling

```python
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Try/Except/Else/Finally
def read_config(filepath: str) -> dict:
    try:
        with open(filepath, "r") as f:
            import json
            return json.load(f)
    except FileNotFoundError:
        logger.error(f"Config file not found: {filepath}")
        raise
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in {filepath}: {e}")
        raise ValueError(f"Invalid config format") from e
    except Exception as e:
        logger.exception(f"Unexpected error reading config")
        raise
    else:
        logger.info("Config loaded successfully")  # Chỉ chạy nếu không có exception
    finally:
        logger.debug("read_config completed")  # Luôn chạy

# Custom Exceptions
class DeploymentError(Exception):
    """Raised when deployment fails."""
    def __init__(self, service: str, reason: str):
        self.service = service
        self.reason = reason
        super().__init__(f"Failed to deploy {service}: {reason}")

class RollbackError(DeploymentError):
    """Raised when rollback fails."""
    pass

# Sử dụng
def deploy_service(name: str):
    try:
        # ... deploy logic
        pass
    except TimeoutError:
        raise DeploymentError(name, "Deployment timed out after 10 minutes")
```

---

## 5. File & OS Operations

```python
import os
import shutil
from pathlib import Path  # Modern way (prefer this)

# Path operations
home = Path.home()
config_dir = home / ".config" / "myapp"
config_file = config_dir / "settings.json"

# Create directories
config_dir.mkdir(parents=True, exist_ok=True)

# File operations
with config_file.open("w") as f:
    import json
    json.dump({"env": "production"}, f, indent=2)

# Read file
content = config_file.read_text()
data = json.loads(content)

# List files
logs_dir = Path("/var/log/myapp")
log_files = list(logs_dir.glob("*.log"))
recent_logs = sorted(log_files, key=lambda f: f.stat().st_mtime, reverse=True)

# Path info
print(config_file.name)        # "settings.json"
print(config_file.stem)        # "settings"
print(config_file.suffix)      # ".json"
print(config_file.parent)      # ~/.config/myapp
print(config_file.exists())    # True/False

# OS operations
os.environ.get("DATABASE_URL", "localhost:5432")
os.getcwd()                     # Current directory

# Run system commands (subprocess - LUÔN dùng thay vì os.system)
import subprocess

result = subprocess.run(
    ["kubectl", "get", "pods", "-n", "production"],
    capture_output=True,
    text=True,
    check=True     # Raise exception nếu returncode != 0
)
print(result.stdout)

# Run với shell (cẩn thận injection)
result = subprocess.run(
    "kubectl get pods | grep Running",
    shell=True,
    capture_output=True,
    text=True
)
```

---

## 6. Modules & Packages

```python
# Import styles
import os                           # Full module
from pathlib import Path            # Specific class
from subprocess import run, PIPE    # Multiple imports
import json as j                    # Alias

# Standard library quan trọng cho DevOps:
import os           # OS interface, env vars
import sys          # Python interpreter info
import subprocess   # Run commands
import json         # JSON encode/decode
import yaml         # (pip install pyyaml) YAML
import re           # Regular expressions
import datetime     # Date/time
import logging      # Structured logging
import argparse     # CLI argument parsing
import pathlib      # File paths
import shutil       # High-level file operations
import tempfile     # Temporary files
import threading    # Multithreading
import concurrent.futures  # Thread/process pools
import hashlib      # Hashing
import base64       # Encoding
import csv          # CSV files
import configparser # INI config files
```

---

## 7. Ví Dụ Thực Tế: Script Rotate Logs

```python
#!/usr/bin/env python3
"""Log rotation script for DevOps."""

import os
import gzip
import shutil
import logging
import argparse
from pathlib import Path
from datetime import datetime, timedelta

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

def rotate_log(log_file: Path, max_size_mb: int = 100, keep_days: int = 30) -> bool:
    """Rotate a log file if it exceeds max_size_mb."""
    if not log_file.exists():
        logger.warning(f"Log file not found: {log_file}")
        return False

    size_mb = log_file.stat().st_size / (1024 * 1024)
    if size_mb < max_size_mb:
        logger.debug(f"{log_file.name}: {size_mb:.1f}MB (below threshold)")
        return False

    # Rotate: compress with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    rotated = log_file.parent / f"{log_file.stem}_{timestamp}.log.gz"

    with log_file.open("rb") as f_in:
        with gzip.open(rotated, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)

    # Clear original file (not delete, so service keeps writing)
    log_file.write_bytes(b"")
    logger.info(f"Rotated {log_file.name} ({size_mb:.1f}MB) → {rotated.name}")
    return True

def cleanup_old_logs(log_dir: Path, keep_days: int):
    """Delete compressed logs older than keep_days."""
    cutoff = datetime.now() - timedelta(days=keep_days)
    deleted = 0

    for gz_file in log_dir.glob("*.log.gz"):
        mtime = datetime.fromtimestamp(gz_file.stat().st_mtime)
        if mtime < cutoff:
            gz_file.unlink()
            deleted += 1
            logger.info(f"Deleted old log: {gz_file.name}")

    logger.info(f"Cleanup: deleted {deleted} old log files")

def main():
    parser = argparse.ArgumentParser(description="Log rotation utility")
    parser.add_argument("log_dir", help="Directory containing log files")
    parser.add_argument("--max-size", type=int, default=100, help="Max size in MB")
    parser.add_argument("--keep-days", type=int, default=30, help="Days to keep rotated logs")
    args = parser.parse_args()

    log_dir = Path(args.log_dir)
    if not log_dir.is_dir():
        logger.error(f"Not a directory: {log_dir}")
        raise SystemExit(1)

    rotated = 0
    for log_file in log_dir.glob("*.log"):
        if rotate_log(log_file, args.max_size, args.keep_days):
            rotated += 1

    cleanup_old_logs(log_dir, args.keep_days)
    logger.info(f"Done: rotated {rotated} log files")

if __name__ == "__main__":
    main()
```

```bash
# Chạy script
python3 rotate_logs.py /var/log/myapp --max-size 50 --keep-days 7

# Thêm vào crontab
0 2 * * * /usr/bin/python3 /opt/scripts/rotate_logs.py /var/log/myapp
```

---

> **Tiếp theo: P2** - OOP, Modules, Testing, Azure SDK
