# 🐍 PYTHON TOÀN TẬP - PHẦN 2: OOP, TESTING & AZURE SDK

---

## 1. Object-Oriented Programming (OOP)

### 1.1 Classes & Instances
```python
from dataclasses import dataclass, field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class PodStatus(Enum):
    RUNNING = "Running"
    PENDING = "Pending"
    FAILED = "Failed"
    CRASHLOOP = "CrashLoopBackOff"

@dataclass
class Pod:
    """Represents a Kubernetes Pod."""
    name: str
    namespace: str
    image: str
    status: PodStatus = PodStatus.PENDING
    restarts: int = 0
    created_at: datetime = field(default_factory=datetime.utcnow)
    labels: dict = field(default_factory=dict)

    def is_healthy(self) -> bool:
        return self.status == PodStatus.RUNNING and self.restarts < 5

    def __repr__(self) -> str:
        return f"Pod({self.name}/{self.namespace}, status={self.status.value})"

# Dùng
pod = Pod(
    name="api-pod-abc",
    namespace="production",
    image="myapp:1.2.0",
    status=PodStatus.RUNNING,
    labels={"app": "api", "version": "1.2.0"}
)
print(pod.is_healthy())  # True
print(pod)               # Pod(api-pod-abc/production, status=Running)
```

### 1.2 Inheritance & Polymorphism
```python
from abc import ABC, abstractmethod

class CloudResource(ABC):
    """Base class cho tất cả cloud resources."""
    
    def __init__(self, name: str, resource_group: str, location: str):
        self.name = name
        self.resource_group = resource_group
        self.location = location
        self._created_at = datetime.utcnow()

    @abstractmethod
    def provision(self) -> bool:
        """Provision resource. Must be implemented by subclasses."""
        ...

    @abstractmethod
    def deprovision(self) -> bool:
        """Delete resource."""
        ...

    def get_info(self) -> dict:
        return {
            "name": self.name,
            "resource_group": self.resource_group,
            "location": self.location,
            "created_at": self._created_at.isoformat()
        }

class AzureVM(CloudResource):
    def __init__(self, name: str, resource_group: str, location: str,
                 vm_size: str = "Standard_B2s", os_image: str = "Ubuntu2204"):
        super().__init__(name, resource_group, location)
        self.vm_size = vm_size
        self.os_image = os_image

    def provision(self) -> bool:
        print(f"Provisioning VM: {self.name} ({self.vm_size})")
        # Azure SDK call here
        return True

    def deprovision(self) -> bool:
        print(f"Deleting VM: {self.name}")
        return True

    def resize(self, new_size: str) -> bool:
        print(f"Resizing {self.name}: {self.vm_size} → {new_size}")
        self.vm_size = new_size
        return True

class AKSCluster(CloudResource):
    def __init__(self, name: str, resource_group: str, location: str,
                 node_count: int = 3, node_vm_size: str = "Standard_D4s_v5"):
        super().__init__(name, resource_group, location)
        self.node_count = node_count
        self.node_vm_size = node_vm_size

    def provision(self) -> bool:
        print(f"Provisioning AKS: {self.name} ({self.node_count} nodes)")
        return True

    def deprovision(self) -> bool:
        print(f"Deleting AKS cluster: {self.name}")
        return True

    def scale(self, count: int) -> bool:
        print(f"Scaling {self.name}: {self.node_count} → {count} nodes")
        self.node_count = count
        return True

# Polymorphism
resources: List[CloudResource] = [
    AzureVM("vm-web-01", "myapp-rg", "southeastasia"),
    AKSCluster("aks-prod", "myapp-rg", "southeastasia", node_count=5),
]

for resource in resources:
    resource.provision()   # Mỗi class có implementation riêng
    print(resource.get_info())  # Shared method từ base class
```

### 1.3 Context Managers
```python
from contextlib import contextmanager
import time

@contextmanager
def timer(operation_name: str):
    """Context manager để measure thời gian."""
    start = time.perf_counter()
    print(f"Starting: {operation_name}")
    try:
        yield
    finally:
        elapsed = time.perf_counter() - start
        print(f"Completed: {operation_name} in {elapsed:.3f}s")

with timer("database migration"):
    time.sleep(0.5)   # Simulate work
# Starting: database migration
# Completed: database migration in 0.501s

# Dùng class
class TempDirectory:
    """Create and auto-cleanup temp directory."""
    def __init__(self, prefix="devops_"):
        self.prefix = prefix
        self.path = None

    def __enter__(self) -> Path:
        import tempfile
        self.path = Path(tempfile.mkdtemp(prefix=self.prefix))
        print(f"Created temp dir: {self.path}")
        return self.path

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.path and self.path.exists():
            shutil.rmtree(self.path)
            print(f"Cleaned up: {self.path}")
        return False  # Don't suppress exceptions

with TempDirectory() as tmpdir:
    (tmpdir / "config.yaml").write_text("key: value")
    # Process files...
# Auto cleanup khi exit block
```

---

## 2. Testing với pytest

### 2.1 Unit Tests
```python
# tests/test_pod.py
import pytest
from datetime import datetime
from unittest.mock import MagicMock, patch

# Import module cần test
from myapp.kubernetes import Pod, PodStatus, PodManager

class TestPod:
    """Unit tests cho Pod class."""

    def test_healthy_pod(self):
        pod = Pod("api", "prod", "nginx:latest", PodStatus.RUNNING, restarts=0)
        assert pod.is_healthy() is True

    def test_unhealthy_pod_too_many_restarts(self):
        pod = Pod("api", "prod", "nginx:latest", PodStatus.RUNNING, restarts=10)
        assert pod.is_healthy() is False

    def test_unhealthy_pod_bad_status(self):
        pod = Pod("api", "prod", "nginx:latest", PodStatus.CRASHLOOP, restarts=0)
        assert pod.is_healthy() is False

    def test_pod_repr(self):
        pod = Pod("my-pod", "default", "nginx:latest", PodStatus.RUNNING)
        assert "my-pod" in repr(pod)
        assert "Running" in repr(pod)

    @pytest.mark.parametrize("restarts,expected", [
        (0, True),
        (4, True),
        (5, False),
        (100, False),
    ])
    def test_restart_threshold(self, restarts, expected):
        pod = Pod("api", "prod", "nginx:latest", PodStatus.RUNNING, restarts=restarts)
        assert pod.is_healthy() is expected


class TestPodManager:
    """Tests với mocking."""

    @pytest.fixture
    def mock_k8s_client(self):
        """Fixture: mock Kubernetes API client."""
        client = MagicMock()
        client.list_namespaced_pod.return_value.items = []
        return client

    @pytest.fixture
    def manager(self, mock_k8s_client):
        return PodManager(client=mock_k8s_client)

    def test_get_pods_returns_empty_list(self, manager, mock_k8s_client):
        pods = manager.get_pods("production")
        assert pods == []
        mock_k8s_client.list_namespaced_pod.assert_called_once_with("production")

    @patch("myapp.kubernetes.requests.get")
    def test_health_check_success(self, mock_get):
        mock_get.return_value.status_code = 200
        mock_get.return_value.json.return_value = {"status": "ok"}
        
        result = check_app_health("http://localhost:3000/health")
        assert result is True
        mock_get.assert_called_once()

    def test_raises_on_api_error(self, manager, mock_k8s_client):
        mock_k8s_client.list_namespaced_pod.side_effect = Exception("API timeout")
        
        with pytest.raises(Exception, match="API timeout"):
            manager.get_pods("production")
```

### 2.2 Fixtures & Conftest
```python
# tests/conftest.py
import pytest
from pathlib import Path
import json

@pytest.fixture(scope="session")
def test_data_dir():
    return Path(__file__).parent / "data"

@pytest.fixture
def sample_config(tmp_path) -> Path:
    """Create a temporary config file."""
    config = {
        "database": {"host": "localhost", "port": 5432},
        "app": {"debug": False, "workers": 4}
    }
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(config))
    return config_file

@pytest.fixture(scope="session")
def azure_credentials():
    """Load test Azure credentials (from env vars)."""
    import os
    return {
        "client_id": os.environ.get("TEST_AZURE_CLIENT_ID", "test-client-id"),
        "client_secret": os.environ.get("TEST_AZURE_CLIENT_SECRET", "test-secret"),
        "tenant_id": os.environ.get("TEST_AZURE_TENANT_ID", "test-tenant"),
        "subscription_id": os.environ.get("TEST_AZURE_SUBSCRIPTION_ID", "test-sub"),
    }

# Dùng trong test:
def test_config_loading(sample_config):
    config = load_config(sample_config)
    assert config["database"]["port"] == 5432
```

### 2.3 Chạy Tests
```bash
# Chạy tất cả tests
pytest

# Với coverage
pytest --cov=myapp --cov-report=html --cov-report=term-missing

# Chỉ unit tests (không integration)
pytest -m "not integration" -v

# Parallel execution
pytest -n 4   # pip install pytest-xdist

# Specific file/function
pytest tests/test_pod.py::TestPod::test_healthy_pod -v

# Stop on first failure
pytest -x

# Output format
pytest --tb=short   # Short traceback
pytest -q           # Quiet mode
```

---

## 3. Azure SDK cho Python

### 3.1 Cài Đặt
```bash
pip install azure-identity azure-mgmt-resource azure-mgmt-compute \
            azure-mgmt-containerservice azure-mgmt-storage \
            azure-mgmt-monitor azure-keyvault-secrets
```

### 3.2 Authentication
```python
from azure.identity import (
    DefaultAzureCredential,
    ClientSecretCredential,
    ManagedIdentityCredential,
    AzureCliCredential
)

# DefaultAzureCredential: Thử nhiều methods tự động
# 1. Environment variables (AZURE_CLIENT_ID, etc.)
# 2. Managed Identity (khi chạy trong Azure)
# 3. Azure CLI (az login)
# Phù hợp cho cả dev và production
credential = DefaultAzureCredential()

# Explicit Service Principal (CI/CD)
credential = ClientSecretCredential(
    tenant_id=os.environ["AZURE_TENANT_ID"],
    client_id=os.environ["AZURE_CLIENT_ID"],
    client_secret=os.environ["AZURE_CLIENT_SECRET"]
)

# Managed Identity (trên Azure VM/AKS - không cần secret!)
credential = ManagedIdentityCredential()

# Local dev
credential = AzureCliCredential()
```

### 3.3 Quản Lý Azure Resources
```python
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.containerservice import ContainerServiceClient
from azure.identity import DefaultAzureCredential
import os

SUBSCRIPTION_ID = os.environ["AZURE_SUBSCRIPTION_ID"]
credential = DefaultAzureCredential()

# Resource Groups
resource_client = ResourceManagementClient(credential, SUBSCRIPTION_ID)

def create_resource_group(name: str, location: str, tags: dict = None) -> dict:
    """Create or update an Azure Resource Group."""
    result = resource_client.resource_groups.create_or_update(
        name,
        {"location": location, "tags": tags or {}}
    )
    print(f"Resource Group '{result.name}' created in '{result.location}'")
    return {"name": result.name, "location": result.location, "id": result.id}

def list_resource_groups() -> list:
    """List all resource groups in subscription."""
    groups = resource_client.resource_groups.list()
    return [{"name": g.name, "location": g.location, "tags": g.tags} for g in groups]

# VMs
compute_client = ComputeManagementClient(credential, SUBSCRIPTION_ID)

def list_vms(resource_group: str) -> list:
    """List all VMs in a resource group."""
    vms = compute_client.virtual_machines.list(resource_group)
    result = []
    for vm in vms:
        instance_view = compute_client.virtual_machines.instance_view(
            resource_group, vm.name
        )
        statuses = [s.display_status for s in instance_view.statuses]
        result.append({
            "name": vm.name,
            "size": vm.hardware_profile.vm_size,
            "location": vm.location,
            "status": statuses
        })
    return result

def start_vm(resource_group: str, vm_name: str):
    """Start a stopped VM (async operation)."""
    poller = compute_client.virtual_machines.begin_start(resource_group, vm_name)
    result = poller.result()  # Wait for completion
    print(f"VM '{vm_name}' started successfully")

# AKS
aks_client = ContainerServiceClient(credential, SUBSCRIPTION_ID)

def get_aks_clusters(resource_group: str) -> list:
    """List all AKS clusters."""
    clusters = aks_client.managed_clusters.list_by_resource_group(resource_group)
    return [{
        "name": c.name,
        "kubernetes_version": c.kubernetes_version,
        "node_count": c.agent_pool_profiles[0].count if c.agent_pool_profiles else 0,
        "location": c.location,
        "provisioning_state": c.provisioning_state
    } for c in clusters]

def scale_aks_node_pool(resource_group: str, cluster_name: str,
                         node_pool: str, count: int):
    """Scale an AKS node pool."""
    agent_pool = aks_client.agent_pools.get(resource_group, cluster_name, node_pool)
    agent_pool.count = count
    
    poller = aks_client.agent_pools.begin_create_or_update(
        resource_group, cluster_name, node_pool, agent_pool
    )
    poller.result()
    print(f"Node pool '{node_pool}' scaled to {count} nodes")
```

### 3.4 Azure Key Vault
```python
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

def get_secrets_client(vault_name: str) -> SecretClient:
    vault_url = f"https://{vault_name}.vault.azure.net/"
    return SecretClient(vault_url=vault_url, credential=DefaultAzureCredential())

def get_secret(vault_name: str, secret_name: str) -> str:
    """Retrieve a secret value from Azure Key Vault."""
    client = get_secrets_client(vault_name)
    secret = client.get_secret(secret_name)
    return secret.value

def set_secret(vault_name: str, secret_name: str, value: str) -> None:
    """Store a secret in Azure Key Vault."""
    client = get_secrets_client(vault_name)
    client.set_secret(secret_name, value)
    print(f"Secret '{secret_name}' stored in '{vault_name}'")

def rotate_secret(vault_name: str, secret_name: str, new_value: str) -> None:
    """Rotate a secret (set new version)."""
    set_secret(vault_name, secret_name, new_value)
    print(f"Secret '{secret_name}' rotated successfully")

# Ví dụ sử dụng
db_password = get_secret("kv-myapp-prod-001", "db-password")
api_key = get_secret("kv-myapp-prod-001", "external-api-key")
```

### 3.5 Azure Monitor - Đọc Metrics
```python
from azure.mgmt.monitor import MonitorManagementClient
from datetime import datetime, timedelta, timezone

monitor_client = MonitorManagementClient(credential, SUBSCRIPTION_ID)

def get_vm_cpu_usage(resource_group: str, vm_name: str, hours: int = 1) -> list:
    """Get CPU usage metrics for a VM."""
    resource_id = (
        f"/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/{resource_group}"
        f"/providers/Microsoft.Compute/virtualMachines/{vm_name}"
    )
    
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(hours=hours)
    
    metrics = monitor_client.metrics.list(
        resource_id,
        timespan=f"{start_time.isoformat()}/{end_time.isoformat()}",
        interval="PT5M",   # 5-minute intervals
        metricnames="Percentage CPU",
        aggregation="Average"
    )
    
    results = []
    for metric in metrics.value:
        for series in metric.timeseries:
            for dp in series.data:
                if dp.average is not None:
                    results.append({
                        "timestamp": dp.timestamp.isoformat(),
                        "cpu_percent": round(dp.average, 2)
                    })
    return results

# Sử dụng
cpu_data = get_vm_cpu_usage("myapp-rg", "vm-web-01", hours=2)
avg_cpu = sum(d["cpu_percent"] for d in cpu_data) / len(cpu_data) if cpu_data else 0
print(f"Average CPU (last 2h): {avg_cpu:.1f}%")
```

---

> **Tiếp theo: P3** - HTTP APIs, Async, Docker SDK, CI Scripting
