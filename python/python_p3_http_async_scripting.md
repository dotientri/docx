# ---
markmap:
    title: "Python — HTTP, Async & DevOps Scripting"
    collapse: false
# ---

# 🐍 PYTHON TOÀN TẬP - PHẦN 3: HTTP, ASYNC, DEVOPS SCRIPTING

## Theory
- Use synchronous (`requests`) and asynchronous (`httpx`/`asyncio`) approaches appropriately: sync for simple tasks, async for high-concurrency I/O-bound work.

## Practice
- Create robust HTTP sessions with retries and timeouts, use `httpx.AsyncClient` for concurrent health checks, and wrap network calls with proper exception handling and backoff.

## 1. HTTP Requests (requests & httpx)

### 1.1 requests (Synchronous)
```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import time

# Basic usage
response = requests.get("https://api.github.com/repos/kubernetes/kubernetes")
response.raise_for_status()   # Raise exception nếu 4xx/5xx
data = response.json()
print(f"Stars: {data['stargazers_count']}")

# Session với retry và timeout
def create_session(retries: int = 3, backoff_factor: float = 1.0) -> requests.Session:
    """Create a robust HTTP session with retry logic."""
    session = requests.Session()
    
    retry = Retry(
        total=retries,
        backoff_factor=backoff_factor,  # 1s, 2s, 4s
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET", "POST", "PUT", "DELETE"]
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session

session = create_session()

# POST với JSON body
def create_kubernetes_secret(api_url: str, token: str, namespace: str,
                              name: str, data: dict) -> dict:
    """Create a Kubernetes secret via API."""
    import base64
    
    encoded_data = {k: base64.b64encode(v.encode()).decode() for k, v in data.items()}
    
    payload = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": name, "namespace": namespace},
        "type": "Opaque",
        "data": encoded_data
    }
    
    response = session.post(
        f"{api_url}/api/v1/namespaces/{namespace}/secrets",
        json=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        },
        timeout=30,
        verify=False  # Development only!
    )
    response.raise_for_status()
    return response.json()

# Health check với timeout
def check_endpoint(url: str, timeout: int = 5) -> dict:
    try:
        start = time.monotonic()
        resp = requests.get(url, timeout=timeout)
        latency_ms = (time.monotonic() - start) * 1000
        return {
            "url": url,
            "status_code": resp.status_code,
            "healthy": resp.status_code == 200,
            "latency_ms": round(latency_ms, 2)
        }
    except requests.exceptions.Timeout:
        return {"url": url, "healthy": False, "error": "timeout"}
    except requests.exceptions.ConnectionError:
        return {"url": url, "healthy": False, "error": "connection_error"}
```

### 1.2 Async HTTP với httpx
```python
import asyncio
import httpx
from typing import List

async def check_services_async(urls: List[str]) -> List[dict]:
    """Check multiple service health endpoints concurrently."""
    async with httpx.AsyncClient(timeout=5.0) as client:
        tasks = [check_one(client, url) for url in urls]
        results = await asyncio.gather(*tasks, return_exceptions=True)
    return results

async def check_one(client: httpx.AsyncClient, url: str) -> dict:
    try:
        resp = await client.get(url)
        return {"url": url, "status": resp.status_code, "healthy": resp.status_code < 400}
    except Exception as e:
        return {"url": url, "healthy": False, "error": str(e)}

# Chạy
urls = [
    "http://api.prod.local/health",
    "http://worker.prod.local/health",
    "http://scheduler.prod.local/health",
]
results = asyncio.run(check_services_async(urls))
for r in results:
    status = "✅" if r["healthy"] else "❌"
    print(f"{status} {r['url']}")
```


## 2. Async Python (asyncio)

### 2.1 Coroutines & Tasks
```python
import asyncio
import time

# Coroutine
async def fetch_pod_metrics(pod_name: str) -> dict:
    """Simulate async metrics fetch."""
    await asyncio.sleep(0.5)   # Non-blocking wait (thay vì time.sleep)
    return {"pod": pod_name, "cpu": 45.2, "memory": 256}

# Sequential (chậm)
async def fetch_all_sequential(pods: list) -> list:
    results = []
    for pod in pods:
        result = await fetch_pod_metrics(pod)
        results.append(result)
    return results

# Concurrent (nhanh hơn nhiều)
async def fetch_all_concurrent(pods: list) -> list:
    tasks = [fetch_pod_metrics(pod) for pod in pods]
    return await asyncio.gather(*tasks)

# So sánh
pods = [f"pod-{i}" for i in range(10)]

start = time.monotonic()
asyncio.run(fetch_all_sequential(pods))
print(f"Sequential: {time.monotonic()-start:.2f}s")  # ~5.0s

start = time.monotonic()
asyncio.run(fetch_all_concurrent(pods))
print(f"Concurrent: {time.monotonic()-start:.2f}s")  # ~0.5s
```

### 2.2 Async Context Manager & Queue
```python
import asyncio
from asyncio import Queue

async def producer(queue: Queue, items: list):
    """Put work items into queue."""
    for item in items:
        await queue.put(item)
        print(f"Produced: {item}")
    await queue.put(None)  # Sentinel to signal done

async def consumer(queue: Queue, worker_id: int):
    """Process work items from queue."""
    while True:
        item = await queue.get()
        if item is None:
            await queue.put(None)  # Pass sentinel to next consumer
            break
        await asyncio.sleep(0.1)  # Simulate work
        print(f"Worker {worker_id} processed: {item}")
        queue.task_done()

async def main():
    queue = Queue(maxsize=5)
    pods = [f"pod-{i}" for i in range(20)]
    
    # 1 producer, 4 consumers
    await asyncio.gather(
        producer(queue, pods),
        *[consumer(queue, i) for i in range(4)]
    )

asyncio.run(main())
```


## 3. Docker SDK cho Python

### 3.1 Manage Containers & Images
```python
import docker
from docker.errors import ImageNotFound, ContainerError, APIError

client = docker.from_env()   # Connect to local Docker daemon

# List running containers
def list_running_containers() -> list:
    containers = client.containers.list()
    return [{
        "id": c.short_id,
        "name": c.name,
        "image": c.image.tags[0] if c.image.tags else "unknown",
        "status": c.status
    } for c in containers]

# Build image
def build_image(path: str, tag: str, build_args: dict = None) -> str:
    """Build Docker image from Dockerfile."""
    print(f"Building image: {tag}")
    image, logs = client.images.build(
        path=path,
        tag=tag,
        buildargs=build_args or {},
        rm=True   # Remove intermediate containers
    )
    for line in logs:
        if "stream" in line:
            print(line["stream"].strip(), end="")
    return image.id

# Pull image
def pull_image(image_name: str) -> None:
    try:
        client.images.pull(image_name)
        print(f"Pulled: {image_name}")
    except ImageNotFound:
        raise ValueError(f"Image not found: {image_name}")

# Run container
def run_container(image: str, command: str = None,
                  environment: dict = None, ports: dict = None) -> str:
    """Run container and return container ID."""
    container = client.containers.run(
        image,
        command=command,
        environment=environment or {},
        ports=ports or {},
        detach=True,    # Non-blocking
        auto_remove=True
    )
    return container.id

# Container logs
def get_container_logs(container_name: str, lines: int = 100) -> str:
    container = client.containers.get(container_name)
    return container.logs(tail=lines, timestamps=True).decode()

# Prune unused resources
def cleanup_docker():
    result = client.containers.prune()   # Stopped containers
    images_result = client.images.prune(filters={"dangling": True})
    print(f"Removed containers: {result.get('ContainersDeleted', [])}")
    print(f"Freed space: {images_result.get('SpaceReclaimed', 0) / 1024 / 1024:.1f}MB")
```


## 4. DevOps Automation Scripts

### 4.1 Script: Kubernetes Pod Health Monitor
```python
#!/usr/bin/env python3
"""Monitor Kubernetes pod health and alert on issues."""

import subprocess
import json
import time
import logging
import os
import argparse
from dataclasses import dataclass
from typing import List, Optional
import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

@dataclass
class PodInfo:
    name: str
    namespace: str
    status: str
    restarts: int
    image: str
    node: str

def get_pods(namespace: str = "default") -> List[PodInfo]:
    """Get pod information via kubectl."""
    result = subprocess.run(
        ["kubectl", "get", "pods", "-n", namespace, "-o", "json"],
        capture_output=True, text=True, check=True
    )
    data = json.loads(result.stdout)
    
    pods = []
    for item in data.get("items", []):
        meta = item["metadata"]
        spec = item["spec"]
        status = item["status"]
        
        container_statuses = status.get("containerStatuses", [{}])
        restarts = sum(cs.get("restartCount", 0) for cs in container_statuses)
        
        pods.append(PodInfo(
            name=meta["name"],
            namespace=meta["namespace"],
            status=status.get("phase", "Unknown"),
            restarts=restarts,
            image=spec["containers"][0]["image"] if spec.get("containers") else "unknown",
            node=spec.get("nodeName", "unknown")
        ))
    return pods

def send_slack_alert(webhook_url: str, message: str, severity: str = "warning"):
    """Send alert to Slack channel."""
    color_map = {"info": "#36a64f", "warning": "#ff9900", "critical": "#ff0000"}
    payload = {
        "attachments": [{
            "color": color_map.get(severity, "#ff9900"),
            "text": message,
            "footer": f"K8s Monitor | {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}"
        }]
    }
    try:
        response = requests.post(webhook_url, json=payload, timeout=5)
        response.raise_for_status()
    except Exception as e:
        logger.error(f"Failed to send Slack alert: {e}")

def monitor_pods(namespace: str, max_restarts: int = 5,
                 slack_webhook: Optional[str] = None):
    """Monitor pods and alert on issues."""
    pods = get_pods(namespace)
    
    issues = []
    for pod in pods:
        if pod.status not in ("Running", "Succeeded"):
            issues.append(f"⚠️ Pod `{pod.name}` status: `{pod.status}`")
        if pod.restarts > max_restarts:
            issues.append(f"🔄 Pod `{pod.name}` has {pod.restarts} restarts")
    
    if issues and slack_webhook:
        message = f"*K8s Alert - namespace: {namespace}*\n" + "\n".join(issues)
        send_slack_alert(slack_webhook, message, severity="warning")
        logger.warning(f"Sent alert: {len(issues)} issues found")
    else:
        logger.info(f"All {len(pods)} pods healthy in namespace '{namespace}'")
    
    return issues

def main():
    parser = argparse.ArgumentParser(description="Kubernetes Pod Monitor")
    parser.add_argument("-n", "--namespace", default="default")
    parser.add_argument("--max-restarts", type=int, default=5)
    parser.add_argument("--interval", type=int, default=60, help="Check interval seconds")
    parser.add_argument("--slack-webhook", default=os.environ.get("SLACK_WEBHOOK_URL"))
    parser.add_argument("--once", action="store_true", help="Run once and exit")
    args = parser.parse_args()

    logger.info(f"Starting pod monitor for namespace: {args.namespace}")
    
    if args.once:
        monitor_pods(args.namespace, args.max_restarts, args.slack_webhook)
        return
    
    while True:
        monitor_pods(args.namespace, args.max_restarts, args.slack_webhook)
        time.sleep(args.interval)

if __name__ == "__main__":
    main()
```

```bash
# Chạy
python3 pod_monitor.py -n production --max-restarts 3 --interval 30

# Hoặc một lần
python3 pod_monitor.py -n production --once

# Với Slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/xxx python3 pod_monitor.py -n production
```

### 4.2 Script: Azure Cost Report
```python
#!/usr/bin/env python3
"""Generate daily Azure cost report."""

from azure.mgmt.costmanagement import CostManagementClient
from azure.identity import DefaultAzureCredential
from datetime import datetime, timedelta
import os, json

SUBSCRIPTION_ID = os.environ["AZURE_SUBSCRIPTION_ID"]
credential = DefaultAzureCredential()
cost_client = CostManagementClient(credential)

def get_daily_costs(days: int = 7) -> list:
    """Get daily cost breakdown for last N days."""
    end = datetime.utcnow().date()
    start = end - timedelta(days=days)
    
    scope = f"/subscriptions/{SUBSCRIPTION_ID}"
    
    result = cost_client.query.usage(
        scope,
        parameters={
            "type": "ActualCost",
            "timeframe": "Custom",
            "timePeriod": {
                "from": start.strftime("%Y-%m-%dT00:00:00Z"),
                "to": end.strftime("%Y-%m-%dT23:59:59Z")
            },
            "dataset": {
                "granularity": "Daily",
                "aggregation": {
                    "totalCost": {"name": "Cost", "function": "Sum"}
                },
                "grouping": [{"type": "Dimension", "name": "ResourceGroup"}]
            }
        }
    )
    
    rows = []
    for row in result.rows:
        rows.append({
            "cost": round(row[0], 2),
            "currency": "USD",
            "date": row[1],
            "resource_group": row[2]
        })
    return sorted(rows, key=lambda x: x["cost"], reverse=True)

def format_report(costs: list) -> str:
    total = sum(c["cost"] for c in costs)
    lines = [f"📊 Azure Cost Report (last 7 days)\nTotal: ${total:.2f}\n"]
    lines.append("| Resource Group | Cost |")
    lines.append("|---|---|")
    for c in costs[:10]:
        lines.append(f"| {c['resource_group']} | ${c['cost']:.2f} |")
    return "\n".join(lines)

if __name__ == "__main__":
    costs = get_daily_costs(7)
    print(format_report(costs))
```


## 5. CLI Tools với Click

```python
#!/usr/bin/env python3
"""DevOps CLI tool built with Click."""

import click
import subprocess
import json

@click.group()
@click.option("--verbose", "-v", is_flag=True, help="Enable verbose output")
@click.pass_context
def cli(ctx, verbose):
    """DevOps automation CLI tool."""
    ctx.ensure_object(dict)
    ctx.obj["verbose"] = verbose

@cli.command()
@click.argument("namespace")
@click.option("--output", "-o", type=click.Choice(["table", "json"]), default="table")
@click.pass_context
def pods(ctx, namespace, output):
    """List pods in a namespace."""
    result = subprocess.run(
        ["kubectl", "get", "pods", "-n", namespace, "-o", "json"],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    
    if output == "json":
        click.echo(json.dumps(data, indent=2))
    else:
        for item in data.get("items", []):
            name = item["metadata"]["name"]
            status = item["status"]["phase"]
            color = "green" if status == "Running" else "red"
            click.echo(f"  {click.style(name, fg=color)} [{status}]")

@cli.command()
@click.argument("namespace")
@click.argument("deployment")
@click.argument("image_tag")
def deploy(namespace, deployment, image_tag):
    """Update deployment image tag."""
    click.echo(f"Deploying {deployment}:{image_tag} to {namespace}...")
    
    if click.confirm("Proceed with deployment?"):
        subprocess.run([
            "kubectl", "set", "image",
            f"deployment/{deployment}",
            f"app={deployment}:{image_tag}",
            "-n", namespace
        ], check=True)
        click.secho("✅ Deployment updated!", fg="green")
    else:
        click.secho("Cancelled.", fg="yellow")

if __name__ == "__main__":
    cli()
```

```bash
# Cài và dùng
pip install click
python3 devops_cli.py pods production
python3 devops_cli.py deploy production api-server 1.2.0
```
