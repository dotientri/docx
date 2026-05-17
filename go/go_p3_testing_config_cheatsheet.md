# 🐹 GO TOÀN TẬP - PHẦN 3: TESTING, CONFIG, AZURE SDK & CHEAT SHEET

---

## 1. Testing trong Go

### 1.1 Unit Tests (testing package)
```go
// pods_test.go  (cùng package hoặc package xxx_test)
package kubernetes_test

import (
    "testing"
    "time"

    "github.com/company/mydevops/internal/kubernetes"
)

func TestPodIsHealthy(t *testing.T) {
    t.Run("running pod with no restarts is healthy", func(t *testing.T) {
        pod := kubernetes.Pod{
            Name:      "api-pod",
            Status:    "Running",
            Restarts:  0,
            CreatedAt: time.Now(),
        }
        if !pod.IsHealthy() {
            t.Errorf("expected pod to be healthy, got unhealthy")
        }
    })

    t.Run("pod with too many restarts is unhealthy", func(t *testing.T) {
        pod := kubernetes.Pod{
            Name:     "api-pod",
            Status:   "Running",
            Restarts: 10,
        }
        if pod.IsHealthy() {
            t.Errorf("expected pod to be unhealthy, got healthy")
        }
    })
}

// Table-driven tests (Go idiom)
func TestParseImage(t *testing.T) {
    tests := []struct {
        name      string
        input     string
        wantName  string
        wantTag   string
        wantError bool
    }{
        {"valid image with tag", "nginx:1.25", "nginx", "1.25", false},
        {"image without tag", "nginx", "", "", true},
        {"full registry image", "registry.io/myapp:latest", "registry.io/myapp", "latest", false},
        {"empty string", "", "", "", true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            name, tag, err := kubernetes.ParseImage(tt.input)
            
            if (err != nil) != tt.wantError {
                t.Errorf("ParseImage() error = %v, wantError = %v", err, tt.wantError)
                return
            }
            if name != tt.wantName {
                t.Errorf("ParseImage() name = %q, want %q", name, tt.wantName)
            }
            if tag != tt.wantTag {
                t.Errorf("ParseImage() tag = %q, want %q", tag, tt.wantTag)
            }
        })
    }
}

// Test with mock (using interface)
type MockDeployer struct {
    DeployedImages []string
    ShouldFail     bool
}

func (m *MockDeployer) Deploy(image string) error {
    if m.ShouldFail {
        return errors.New("mock deploy failure")
    }
    m.DeployedImages = append(m.DeployedImages, image)
    return nil
}

func TestDeploymentManager(t *testing.T) {
    mock := &MockDeployer{}
    manager := kubernetes.NewDeploymentManager(mock)
    
    err := manager.DeployAll([]string{"api:1.0", "worker:1.0"})
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if len(mock.DeployedImages) != 2 {
        t.Errorf("expected 2 deployments, got %d", len(mock.DeployedImages))
    }
}
```

### 1.2 HTTP Handler Tests
```go
package api_test

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/company/mydevops/internal/api"
)

func TestHealthHandler(t *testing.T) {
    req := httptest.NewRequest(http.MethodGet, "/health", nil)
    w := httptest.NewRecorder()
    
    api.HealthHandler(w, req)
    
    resp := w.Result()
    if resp.StatusCode != http.StatusOK {
        t.Errorf("expected 200, got %d", resp.StatusCode)
    }
    
    var body map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&body)
    if body["status"] != "ok" {
        t.Errorf("expected status=ok, got %v", body["status"])
    }
}
```

### 1.3 Benchmarks & Coverage
```bash
# Run tests
go test ./...                    # All packages
go test -v ./internal/...        # Verbose, specific path
go test -run TestPodIsHealthy    # Specific test
go test -race ./...              # Race condition detector (MUST use in CI)

# Coverage
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out  # Open browser
go tool cover -func=coverage.out  # Terminal summary

# Benchmarks
go test -bench=. -benchmem ./...

# Example benchmark:
func BenchmarkParseImage(b *testing.B) {
    for i := 0; i < b.N; i++ {
        ParseImage("registry.company.com/myapp:1.2.0")
    }
}
```

---

## 2. JSON & YAML Handling

```go
package main

import (
    "encoding/json"
    "fmt"
    "os"
    "gopkg.in/yaml.v3"  // go get gopkg.in/yaml.v3
)

// JSON struct tags
type Deployment struct {
    APIVersion string   `json:"apiVersion" yaml:"apiVersion"`
    Kind       string   `json:"kind"       yaml:"kind"`
    Metadata   Metadata `json:"metadata"   yaml:"metadata"`
    Spec       DepSpec  `json:"spec"       yaml:"spec"`
}

type Metadata struct {
    Name      string            `json:"name"   yaml:"name"`
    Namespace string            `json:"namespace,omitempty" yaml:"namespace,omitempty"`
    Labels    map[string]string `json:"labels,omitempty"    yaml:"labels,omitempty"`
}

type DepSpec struct {
    Replicas int32 `json:"replicas" yaml:"replicas"`
}

// Marshal to JSON
func toJSON(d *Deployment) ([]byte, error) {
    return json.MarshalIndent(d, "", "  ")
}

// Unmarshal from JSON
func fromJSON(data []byte) (*Deployment, error) {
    var d Deployment
    if err := json.Unmarshal(data, &d); err != nil {
        return nil, err
    }
    return &d, nil
}

// Marshal/Unmarshal YAML
func toYAML(d *Deployment) ([]byte, error) {
    return yaml.Marshal(d)
}

func fromYAML(data []byte) (*Deployment, error) {
    var d Deployment
    if err := yaml.Unmarshal(data, &d); err != nil {
        return nil, err
    }
    return &d, nil
}

// Read YAML file (common in DevOps tools)
func readYAMLFile(path string, out interface{}) error {
    data, err := os.ReadFile(path)
    if err != nil {
        return fmt.Errorf("read file: %w", err)
    }
    return yaml.Unmarshal(data, out)
}

func main() {
    dep := &Deployment{
        APIVersion: "apps/v1",
        Kind:       "Deployment",
        Metadata: Metadata{
            Name:      "api",
            Namespace: "production",
            Labels:    map[string]string{"app": "api"},
        },
        Spec: DepSpec{Replicas: 3},
    }
    
    jsonData, _ := toJSON(dep)
    fmt.Println(string(jsonData))
    
    yamlData, _ := toYAML(dep)
    fmt.Println(string(yamlData))
}
```

---

## 3. Configuration với Viper

```go
package config

import (
    "fmt"
    "github.com/spf13/viper"
)

type Config struct {
    App      AppConfig      `mapstructure:"app"`
    Database DatabaseConfig `mapstructure:"database"`
    Azure    AzureConfig    `mapstructure:"azure"`
    K8s      K8sConfig      `mapstructure:"kubernetes"`
}

type AppConfig struct {
    Name        string `mapstructure:"name"`
    Port        int    `mapstructure:"port"`
    Environment string `mapstructure:"environment"`
    LogLevel    string `mapstructure:"log_level"`
}

type DatabaseConfig struct {
    Host     string `mapstructure:"host"`
    Port     int    `mapstructure:"port"`
    Name     string `mapstructure:"name"`
    Username string `mapstructure:"username"`
    Password string `mapstructure:"password"`
    SSLMode  string `mapstructure:"ssl_mode"`
}

type AzureConfig struct {
    TenantID       string `mapstructure:"tenant_id"`
    ClientID       string `mapstructure:"client_id"`
    ClientSecret   string `mapstructure:"client_secret"`
    SubscriptionID string `mapstructure:"subscription_id"`
    KeyVaultName   string `mapstructure:"key_vault_name"`
}

type K8sConfig struct {
    Kubeconfig string `mapstructure:"kubeconfig"`
    Namespace  string `mapstructure:"namespace"`
}

func Load(configFile string) (*Config, error) {
    v := viper.New()
    
    // Defaults
    v.SetDefault("app.port", 8080)
    v.SetDefault("app.environment", "development")
    v.SetDefault("app.log_level", "info")
    v.SetDefault("database.port", 5432)
    v.SetDefault("database.ssl_mode", "require")
    v.SetDefault("kubernetes.namespace", "default")
    
    // Config file
    if configFile != "" {
        v.SetConfigFile(configFile)
    } else {
        v.SetConfigName("config")
        v.SetConfigType("yaml")
        v.AddConfigPath(".")
        v.AddConfigPath("./config")
        v.AddConfigPath("/etc/myapp")
    }
    
    // Environment variables override config file
    v.AutomaticEnv()
    v.SetEnvPrefix("APP")  // APP_DATABASE_HOST overrides database.host
    
    if err := v.ReadInConfig(); err != nil {
        if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
            return nil, fmt.Errorf("read config: %w", err)
        }
        // Config file not found is ok, use defaults + env
    }
    
    var cfg Config
    if err := v.Unmarshal(&cfg); err != nil {
        return nil, fmt.Errorf("unmarshal config: %w", err)
    }
    return &cfg, nil
}
```

```yaml
# config.yaml example
app:
  name: mydevops-api
  port: 8080
  environment: production
  log_level: info

database:
  host: postgres.prod.internal
  port: 5432
  name: myapp
  username: apiuser
  # password: loaded from env APP_DATABASE_PASSWORD

azure:
  tenant_id: ${AZURE_TENANT_ID}
  client_id: ${AZURE_CLIENT_ID}
  key_vault_name: kv-myapp-prod

kubernetes:
  namespace: production
```

---

## 4. Go Cheat Sheet

```go
// ===== BASIC SYNTAX =====
var x int = 10          // Explicit type
y := 20                 // Short declaration (type inferred)
const Pi = 3.14159      // Constant

// ===== ZERO VALUES =====
var i int       // 0
var s string    // ""
var b bool      // false
var p *int      // nil
var sl []int    // nil (len=0, cap=0)
var m map[string]int  // nil

// ===== TYPE CONVERSIONS =====
i := 42
f := float64(i)
s := fmt.Sprintf("%d", i)  // Int to string
n, _ := strconv.Atoi("42") // String to int

// ===== CONTROL FLOW =====
// If (no parentheses)
if x > 0 {
    fmt.Println("positive")
} else if x < 0 {
    fmt.Println("negative")
} else {
    fmt.Println("zero")
}

// If with init statement
if err := doSomething(); err != nil {
    log.Fatal(err)
}

// Switch (no fallthrough by default)
switch day {
case "Mon", "Tue", "Wed", "Thu", "Fri":
    fmt.Println("Weekday")
case "Sat", "Sun":
    fmt.Println("Weekend")
default:
    fmt.Println("Unknown")
}

// For (only loop in Go)
for i := 0; i < 10; i++ {}   // C-style
for i < 10 {}                  // While-style
for {}                         // Infinite loop

// Range
for i, v := range slice {}    // Index + value
for _, v := range slice {}    // Value only
for k, v := range myMap {}    // Map key + value
for ch := range myChannel {}  // Channel receive

// ===== FUNCTIONS =====
func add(a, b int) int { return a + b }
func swap(a, b int) (int, int) { return b, a }

// Variadic
func sum(nums ...int) int {
    total := 0
    for _, n := range nums {
        total += n
    }
    return total
}
sum(1, 2, 3)         // Direct
sum(nums...)          // Spread slice

// Defer (LIFO)
defer fmt.Println("cleanup")

// ===== GOROUTINES & CHANNELS =====
go func() { fmt.Println("async") }()

ch := make(chan int, 10)  // Buffered
ch <- 42                  // Send
v := <-ch                 // Receive
close(ch)                 // Close

// ===== ERROR HANDLING =====
result, err := someFunc()
if err != nil {
    return fmt.Errorf("context: %w", err)
}

// ===== USEFUL STDLIB =====
import (
    "fmt"        // Print, Sprintf, Errorf
    "os"         // Files, env vars, exit
    "io"         // Reader, Writer interfaces
    "strings"    // String manipulation
    "strconv"    // String conversions
    "time"       // Time, Duration, Sleep
    "math/rand"  // Random numbers
    "sort"       // Sorting
    "encoding/json"  // JSON
    "net/http"   // HTTP client & server
    "sync"       // Mutex, WaitGroup
    "context"    // Context, cancellation
    "log"        // Simple logging
    "path/filepath"  // File paths
    "os/exec"    // Run commands
)

// ===== COMMON PATTERNS =====

// Run command
cmd := exec.Command("kubectl", "get", "pods", "-n", "default")
out, err := cmd.Output()
if err != nil { log.Fatal(err) }
fmt.Println(string(out))

// Read env var with default
func getEnv(key, defaultValue string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return defaultValue
}

// Must helper (panic on error - use in init only)
func mustGetenv(key string) string {
    v := os.Getenv(key)
    if v == "" {
        panic(fmt.Sprintf("required env var %s not set", key))
    }
    return v
}

// Retry with backoff
func retry(attempts int, sleep time.Duration, fn func() error) error {
    for i := 0; i < attempts; i++ {
        if err := fn(); err != nil {
            if i == attempts-1 {
                return err
            }
            time.Sleep(sleep * time.Duration(i+1))
            continue
        }
        return nil
    }
    return nil
}
```

---

## 5. Go Best Practices cho DevOps

| Practice | Reason |
|----------|--------|
| **Accept interfaces, return structs** | Flexibility for callers, concrete types for creators |
| **Handle errors explicitly** – never ignore | Go's idiom, no exceptions |
| **Use context.Context** cho cancellation và deadlines | Production-grade cancellation |
| **Use `sync.WaitGroup` + channels** cho goroutine coordination | Avoid goroutine leaks |
| **Write table-driven tests** | Go idiom, easy to add cases |
| **`-race` flag trong CI** | Catch race conditions early |
| **Single binary deployment** | `go build` → deploy the binary |
| **`log/slog`** (Go 1.21+) thay vì `fmt.Println` | Structured logging |
| **Use `golangci-lint`** | Consistent code quality |
| **`go mod tidy` trong CI** | Keep dependencies clean |

```bash
# Tooling setup
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
golangci-lint run ./...

# Build với version info
go build \
  -ldflags="-X main.version=$(git describe --tags) -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -o myapp ./cmd/main.go
```
