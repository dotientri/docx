---
markmap:
    title: "Go — Fundamentals"
    collapse: false
---

# 🐹 GO TOÀN TẬP - PHẦN 1: FUNDAMENTALS

## Theory
- Go is a compiled, statically-typed language optimized for concurrency and tooling; common in cloud-native ecosystems.

## Practice
- Build single static binaries, write concurrent tools using goroutines/channels, cross-compile for target OS/arch, and add tests and CI.

## 1. Tại Sao Go cho DevOps?

- **Performance**: Compiled, statically typed, fast as C
- **Concurrency**: Goroutines + channels (built-in, không cần library)
- **Single binary**: Compile ra 1 file, deploy dễ (không cần runtime)
- **Docker, Kubernetes, Terraform, Prometheus** đều viết bằng Go
- **Cross-compile**: Build cho linux/amd64 từ Mac chỉ cần set GOOS/GOARCH

```bash
# Cài Go
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

go version   # go version go1.22.0 linux/amd64

# Tạo project
mkdir mydevops && cd mydevops
go mod init github.com/company/mydevops

# Build & run
go build -o myapp ./cmd/main.go
go run ./cmd/main.go

# Cross-compile cho Linux từ Mac
GOOS=linux GOARCH=amd64 go build -o myapp-linux ./cmd/main.go
```


## 2. Basic Syntax

### 2.1 Variables & Types
```go
package main

import "fmt"

func main() {
    // Khai báo với type
    var name string = "DevOps Engineer"
    var count int = 42
    var ratio float64 = 3.14
    var active bool = true

    // Short declaration (prefer this)
    env := "production"
    port := 8080
    
    // Multiple assignment
    host, portNum := "localhost", 5432
    
    // Constants
    const MaxRetries = 3
    const (
        StatusRunning = "Running"
        StatusFailed  = "Failed"
    )
    
    // Zero values (không cần khởi tạo)
    var x int        // 0
    var s string     // ""
    var b bool       // false
    var f float64    // 0.0
    
    fmt.Println(name, count, ratio, active, env, port, host, portNum, x, s, b, f)
}
```

### 2.2 Arrays, Slices & Maps
```go
// ARRAY (fixed size - ít dùng)
var arr [3]string = [3]string{"api", "worker", "db"}
arr2 := [...]int{1, 2, 3, 4, 5}  // Compiler counts

// SLICE (dynamic size - prefer this)
pods := []string{"pod-a", "pod-b", "pod-c"}
pods = append(pods, "pod-d")        // Add element
pods = append(pods, "pod-e", "pod-f") // Add multiple
pods[0]                              // "pod-a"
pods[1:3]                            // ["pod-b", "pod-c"] (slicing)
len(pods)                            // 6
pods = pods[1:]                      // Remove first element

// Make slice với capacity
ips := make([]string, 0, 100)  // len=0, cap=100

// Iterate
for i, pod := range pods {
    fmt.Printf("[%d] %s\n", i, pod)
}
for _, pod := range pods {   // Ignore index
    fmt.Println(pod)
}

// MAP (key-value)
config := map[string]string{
    "host": "localhost",
    "port": "5432",
    "db":   "myapp",
}

// Access (always check existence)
port, ok := config["port"]
if !ok {
    port = "5432"  // default
}

// Add/Update
config["ssl"] = "true"

// Delete
delete(config, "ssl")

// Iterate
for key, value := range config {
    fmt.Printf("%s = %s\n", key, value)
}

// Make map
labels := make(map[string]string)
labels["app"] = "api"
```

### 2.3 Structs
```go
package main

import (
    "fmt"
    "time"
)

// Struct definition
type Pod struct {
    Name      string
    Namespace string
    Image     string
    Status    string
    Restarts  int
    CreatedAt time.Time
    Labels    map[string]string
}

// Constructor function (Go convention)
func NewPod(name, namespace, image string) *Pod {
    return &Pod{
        Name:      name,
        Namespace: namespace,
        Image:     image,
        Status:    "Pending",
        Restarts:  0,
        CreatedAt: time.Now(),
        Labels:    make(map[string]string),
    }
}

// Method (pointer receiver - can modify)
func (p *Pod) SetLabel(key, value string) {
    p.Labels[key] = value
}

// Method (value receiver - read-only)
func (p Pod) IsHealthy() bool {
    return p.Status == "Running" && p.Restarts < 5
}

// Implement Stringer interface
func (p Pod) String() string {
    return fmt.Sprintf("Pod(%s/%s, status=%s)", p.Name, p.Namespace, p.Status)
}

func main() {
    pod := NewPod("api-pod-abc", "production", "myapp:1.0.0")
    pod.Status = "Running"
    pod.SetLabel("app", "api")
    pod.SetLabel("version", "1.0.0")
    
    fmt.Println(pod)           // Pod(api-pod-abc/production, status=Running)
    fmt.Println(pod.IsHealthy()) // true
    
    // Struct embedding (composition)
    type Service struct {
        Pod               // Embed Pod - inherits fields & methods
        Port int
        Protocol string
    }
    
    svc := Service{
        Pod:      *pod,
        Port:     8080,
        Protocol: "TCP",
    }
    fmt.Println(svc.IsHealthy())  // Access Pod's method directly
}
```


## 3. Functions & Interfaces

### 3.1 Functions
```go
package main

import (
    "errors"
    "fmt"
)

// Multiple return values (Go signature)
func parseImage(image string) (name string, tag string, err error) {
    for i, c := range image {
        if c == ':' {
            return image[:i], image[i+1:], nil
        }
    }
    return "", "", fmt.Errorf("invalid image format: %s", image)
}

// Named return values
func divide(a, b float64) (result float64, err error) {
    if b == 0 {
        err = errors.New("division by zero")
        return  // Naked return - returns named values
    }
    result = a / b
    return
}

// Variadic function
func sum(numbers ...int) int {
    total := 0
    for _, n := range numbers {
        total += n
    }
    return total
}

// First-class functions
type FilterFunc func(pod string) bool

func filterPods(pods []string, fn FilterFunc) []string {
    result := make([]string, 0)
    for _, pod := range pods {
        if fn(pod) {
            result = append(result, pod)
        }
    }
    return result
}

// Closures
func makeCounter() func() int {
    count := 0
    return func() int {
        count++
        return count
    }
}

// Defer (LIFO order)
func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()   // Always called when function returns
    
    // ... process file
    return nil
}

func main() {
    name, tag, err := parseImage("nginx:1.25")
    if err != nil {
        panic(err)
    }
    fmt.Printf("Image: %s, Tag: %s\n", name, tag) // Image: nginx, Tag: 1.25
    
    pods := []string{"pod-api", "pod-worker", "pod-db"}
    apiPods := filterPods(pods, func(p string) bool {
        return len(p) > 0 && p[:3] == "pod" // Contains "pod"
    })
    fmt.Println(apiPods)
    
    counter := makeCounter()
    fmt.Println(counter(), counter(), counter())  // 1 2 3
}
```

### 3.2 Interfaces
```go
package main

import "fmt"

// Interface definition
type Deployer interface {
    Deploy(image string) error
    Rollback() error
    Status() string
}

type HealthChecker interface {
    HealthCheck() bool
}

// Compose interfaces
type DeploymentManager interface {
    Deployer
    HealthChecker
}

// Implement interface (implicit - no "implements" keyword)
type KubernetesDeployer struct {
    Namespace  string
    Name       string
    currentTag string
}

func (k *KubernetesDeployer) Deploy(image string) error {
    fmt.Printf("Deploying %s to K8s namespace %s\n", image, k.Namespace)
    k.currentTag = image
    return nil
}

func (k *KubernetesDeployer) Rollback() error {
    fmt.Printf("Rolling back deployment %s\n", k.Name)
    return nil
}

func (k *KubernetesDeployer) Status() string {
    return fmt.Sprintf("Running (image: %s)", k.currentTag)
}

func (k *KubernetesDeployer) HealthCheck() bool {
    return true
}

// Function accepts interface (not concrete type)
func runDeployment(d Deployer, image string) {
    if err := d.Deploy(image); err != nil {
        fmt.Printf("Deploy failed: %v\n", err)
        if err := d.Rollback(); err != nil {
            fmt.Printf("Rollback also failed: %v\n", err)
        }
        return
    }
    fmt.Printf("Deploy success. Status: %s\n", d.Status())
}

func main() {
    deployer := &KubernetesDeployer{
        Namespace: "production",
        Name:      "api",
    }
    runDeployment(deployer, "myapp:1.2.0")
}
```


## 4. Error Handling

```go
package main

import (
    "errors"
    "fmt"
)

// Custom error types
type DeploymentError struct {
    Service string
    Stage   string
    Err     error
}

func (e *DeploymentError) Error() string {
    return fmt.Sprintf("deployment failed for %s at stage %s: %v",
        e.Service, e.Stage, e.Err)
}

func (e *DeploymentError) Unwrap() error {
    return e.Err
}

var (
    ErrNotFound      = errors.New("resource not found")
    ErrUnauthorized  = errors.New("unauthorized")
    ErrTimeout       = errors.New("operation timed out")
)

func deployService(name string) error {
    // Wrap errors with context
    if err := buildImage(name); err != nil {
        return fmt.Errorf("buildImage: %w", err)  // %w = wrappable
    }
    if err := pushToRegistry(name); err != nil {
        return &DeploymentError{
            Service: name,
            Stage:   "push",
            Err:     err,
        }
    }
    return nil
}

func main() {
    err := deployService("api")
    if err != nil {
        // Check specific error type
        var deployErr *DeploymentError
        if errors.As(err, &deployErr) {
            fmt.Printf("Deploy error at stage: %s\n", deployErr.Stage)
        }
        
        // Check sentinel error
        if errors.Is(err, ErrNotFound) {
            fmt.Println("Resource not found")
        }
        
        // Always log full error
        fmt.Printf("Error: %v\n", err)
    }
}

// Panic & Recover (dùng cho unrecoverable errors)
func safeExecute(fn func()) (err error) {
    defer func() {
        if r := recover(); r != nil {
            err = fmt.Errorf("panic: %v", r)
        }
    }()
    fn()
    return nil
}
```


## 5. Packages & Modules

```
Project structure (standard):
mydevops/
├── cmd/
│   └── main.go            # Entry point
├── internal/              # Private packages (không import từ ngoài)
│   ├── kubernetes/
│   │   ├── client.go
│   │   └── pods.go
│   └── azure/
│       ├── auth.go
│       └── resources.go
├── pkg/                   # Public packages (có thể import)
│   ├── logger/
│   │   └── logger.go
│   └── config/
│       └── config.go
├── api/                   # API definitions (protobuf, openapi)
├── scripts/               # Build/deploy scripts
├── Dockerfile
├── go.mod
└── go.sum
```

```go
// go.mod
module github.com/company/mydevops

go 1.22

require (
    github.com/spf13/cobra v1.8.0
    github.com/spf13/viper v1.18.0
    go.uber.org/zap v1.27.0
    k8s.io/client-go v0.29.2
)

// Install dependencies
// go get package@version
// go mod tidy    (remove unused, update go.sum)
// go mod vendor  (download to vendor/ for offline builds)
```
