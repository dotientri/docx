# 🐹 GO TOÀN TẬP - PHẦN 2: CONCURRENCY, HTTP & CLI TOOLS

---

## 1. Concurrency - Goroutines & Channels

### 1.1 Goroutines (Lightweight Threads)
```go
package main

import (
    "fmt"
    "sync"
    "time"
)

func checkHealth(url string, wg *sync.WaitGroup, results chan<- string) {
    defer wg.Done()  // Signal WaitGroup khi goroutine kết thúc
    
    // Simulate HTTP check
    time.Sleep(100 * time.Millisecond)
    results <- fmt.Sprintf("%s: OK", url)
}

func main() {
    urls := []string{
        "http://api.company.com/health",
        "http://worker.company.com/health",
        "http://scheduler.company.com/health",
    }
    
    var wg sync.WaitGroup
    results := make(chan string, len(urls))  // Buffered channel
    
    // Launch goroutines (concurrent)
    for _, url := range urls {
        wg.Add(1)
        go checkHealth(url, &wg, results)
    }
    
    // Wait in background, then close channel
    go func() {
        wg.Wait()
        close(results)
    }()
    
    // Read results
    for result := range results {
        fmt.Println(result)
    }
}
```

### 1.2 Channels - Communication Between Goroutines
```go
package main

import (
    "context"
    "fmt"
    "time"
)

// Worker Pool Pattern (Classic DevOps use case)
func workerPool(jobs <-chan string, results chan<- string, workerID int) {
    for job := range jobs {
        // Process job
        time.Sleep(10 * time.Millisecond)
        results <- fmt.Sprintf("Worker %d processed: %s", workerID, job)
    }
}

func main() {
    const numWorkers = 5
    const numJobs = 20
    
    jobs := make(chan string, numJobs)
    results := make(chan string, numJobs)
    
    // Start workers
    for w := 1; w <= numWorkers; w++ {
        go workerPool(jobs, results, w)
    }
    
    // Send jobs
    for j := 1; j <= numJobs; j++ {
        jobs <- fmt.Sprintf("pod-deploy-%d", j)
    }
    close(jobs)
    
    // Collect results
    for r := 1; r <= numJobs; r++ {
        fmt.Println(<-results)
    }
}

// Select - Handle multiple channels
func monitorWithTimeout(ctx context.Context, alertCh <-chan string) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case alert := <-alertCh:
            fmt.Printf("ALERT: %s\n", alert)
        case <-ticker.C:
            fmt.Println("Heartbeat: All systems normal")
        case <-ctx.Done():
            fmt.Println("Monitoring stopped")
            return
        }
    }
}
```

### 1.3 Mutex - Safe Shared State
```go
package main

import (
    "fmt"
    "sync"
)

type SafeCounter struct {
    mu    sync.Mutex
    count map[string]int
}

func (c *SafeCounter) Increment(key string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count[key]++
}

func (c *SafeCounter) Value(key string) int {
    c.mu.RLock()  // Read lock (multiple readers OK)
    defer c.mu.RUnlock()
    return c.count[key]
}

// sync.Map for concurrent maps (alternative)
func concurrentMapExample() {
    var m sync.Map
    
    // Store
    m.Store("pod-api", "Running")
    m.Store("pod-worker", "Pending")
    
    // Load
    val, ok := m.Load("pod-api")
    if ok {
        fmt.Println(val)  // "Running"
    }
    
    // Range (iterate)
    m.Range(func(key, value interface{}) bool {
        fmt.Printf("%s: %s\n", key, value)
        return true  // Continue iteration
    })
}
```

### 1.4 Context - Cancellation & Deadlines
```go
package main

import (
    "context"
    "fmt"
    "time"
)

func deployWithTimeout(ctx context.Context, service string) error {
    // Create child context with timeout
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    
    done := make(chan error, 1)
    go func() {
        // Simulate long-running deployment
        done <- doActualDeploy(ctx, service)
    }()
    
    select {
    case err := <-done:
        return err
    case <-ctx.Done():
        return fmt.Errorf("deployment timed out: %w", ctx.Err())
    }
}

func doActualDeploy(ctx context.Context, service string) error {
    for i := 0; i < 10; i++ {
        // Check context before each step
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
        
        time.Sleep(1 * time.Second)
        fmt.Printf("Deploying %s: step %d/10\n", service, i+1)
    }
    return nil
}

func main() {
    ctx := context.Background()
    err := deployWithTimeout(ctx, "api-service")
    if err != nil {
        fmt.Printf("Error: %v\n", err)
    }
}
```

---

## 2. HTTP Server (net/http)

### 2.1 Simple HTTP Server
```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "time"
)

type HealthResponse struct {
    Status    string    `json:"status"`
    Timestamp time.Time `json:"timestamp"`
    Version   string    `json:"version"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    
    response := HealthResponse{
        Status:    "ok",
        Timestamp: time.Now().UTC(),
        Version:   "1.0.0",
    }
    json.NewEncoder(w).Encode(response)
}

type podHandler struct {
    db *PodDatabase  // Dependency injection
}

func (h *podHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    switch r.Method {
    case http.MethodGet:
        h.listPods(w, r)
    case http.MethodPost:
        h.createPod(w, r)
    default:
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
    }
}

func (h *podHandler) listPods(w http.ResponseWriter, r *http.Request) {
    namespace := r.URL.Query().Get("namespace")
    if namespace == "" {
        namespace = "default"
    }
    
    pods := h.db.GetPodsByNamespace(namespace)
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(pods)
}

func main() {
    mux := http.NewServeMux()
    
    mux.HandleFunc("/health", healthHandler)
    mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        fmt.Fprint(w, "ready")
    })
    mux.Handle("/api/pods", &podHandler{db: NewPodDatabase()})
    
    // Middleware chain
    handler := loggingMiddleware(rateLimitMiddleware(mux))
    
    server := &http.Server{
        Addr:         ":8080",
        Handler:      handler,
        ReadTimeout:  15 * time.Second,
        WriteTimeout: 15 * time.Second,
        IdleTimeout:  60 * time.Second,
    }
    
    log.Printf("Server starting on :8080")
    if err := server.ListenAndServe(); err != nil {
        log.Fatal(err)
    }
}

// Middleware
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
    })
}
```

### 2.2 HTTP Client
```go
package main

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"
)

type APIClient struct {
    BaseURL    string
    HTTPClient *http.Client
    Token      string
}

func NewAPIClient(baseURL, token string) *APIClient {
    return &APIClient{
        BaseURL: baseURL,
        Token:   token,
        HTTPClient: &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                MaxIdleConns:       100,
                IdleConnTimeout:    90 * time.Second,
                DisableCompression: false,
            },
        },
    }
}

func (c *APIClient) do(ctx context.Context, method, path string, body interface{}) (*http.Response, error) {
    var reqBody *bytes.Reader
    if body != nil {
        b, err := json.Marshal(body)
        if err != nil {
            return nil, fmt.Errorf("marshal body: %w", err)
        }
        reqBody = bytes.NewReader(b)
    } else {
        reqBody = bytes.NewReader(nil)
    }
    
    req, err := http.NewRequestWithContext(ctx, method, c.BaseURL+path, reqBody)
    if err != nil {
        return nil, err
    }
    
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", "Bearer "+c.Token)
    req.Header.Set("User-Agent", "mydevops-client/1.0")
    
    return c.HTTPClient.Do(req)
}

func (c *APIClient) GetPods(ctx context.Context, namespace string) ([]Pod, error) {
    resp, err := c.do(ctx, http.MethodGet, "/api/v1/namespaces/"+namespace+"/pods", nil)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
    }
    
    var result struct {
        Items []Pod `json:"items"`
    }
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, fmt.Errorf("decode response: %w", err)
    }
    return result.Items, nil
}
```

---

## 3. CLI Tools với Cobra

```go
// go get github.com/spf13/cobra@latest
// go get github.com/spf13/viper@latest

package main

import (
    "fmt"
    "os"
    "github.com/spf13/cobra"
    "github.com/spf13/viper"
)

var (
    cfgFile   string
    namespace string
    verbose   bool
)

// Root command
var rootCmd = &cobra.Command{
    Use:   "devops-cli",
    Short: "DevOps automation CLI",
    Long:  "A CLI tool for automating DevOps tasks on Azure and Kubernetes",
    PersistentPreRun: func(cmd *cobra.Command, args []string) {
        if verbose {
            fmt.Println("Verbose mode enabled")
        }
    },
}

// Pods command
var podsCmd = &cobra.Command{
    Use:   "pods",
    Short: "Manage Kubernetes pods",
}

var listPodsCmd = &cobra.Command{
    Use:   "list",
    Short: "List pods in a namespace",
    RunE: func(cmd *cobra.Command, args []string) error {
        fmt.Printf("Listing pods in namespace: %s\n", namespace)
        // ... kubectl or API call
        return nil
    },
}

var deletePodsCmd = &cobra.Command{
    Use:   "delete [pod-name]",
    Short: "Delete a pod",
    Args:  cobra.ExactArgs(1),
    RunE: func(cmd *cobra.Command, args []string) error {
        podName := args[0]
        fmt.Printf("Deleting pod: %s in namespace: %s\n", podName, namespace)
        return nil
    },
}

// Deploy command
var deployCmd = &cobra.Command{
    Use:   "deploy [service] [image-tag]",
    Short: "Deploy a service",
    Args:  cobra.ExactArgs(2),
    RunE: func(cmd *cobra.Command, args []string) error {
        service, tag := args[0], args[1]
        dryRun, _ := cmd.Flags().GetBool("dry-run")
        
        if dryRun {
            fmt.Printf("[DRY RUN] Would deploy %s:%s to %s\n", service, tag, namespace)
            return nil
        }
        
        fmt.Printf("Deploying %s:%s to namespace %s\n", service, tag, namespace)
        return nil
    },
}

func init() {
    cobra.OnInitialize(initConfig)
    
    // Global flags
    rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default: .devops-cli.yaml)")
    rootCmd.PersistentFlags().StringVarP(&namespace, "namespace", "n", "default", "Kubernetes namespace")
    rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output")
    
    // Deploy flags
    deployCmd.Flags().Bool("dry-run", false, "Show what would be deployed without doing it")
    deployCmd.Flags().Int("timeout", 300, "Deployment timeout in seconds")
    
    // Build command tree
    podsCmd.AddCommand(listPodsCmd, deletePodsCmd)
    rootCmd.AddCommand(podsCmd, deployCmd)
}

func initConfig() {
    if cfgFile != "" {
        viper.SetConfigFile(cfgFile)
    } else {
        viper.SetConfigName(".devops-cli")
        viper.SetConfigType("yaml")
        viper.AddConfigPath(".")
        viper.AddConfigPath("$HOME")
    }
    viper.AutomaticEnv()  // Read from environment variables too
    viper.ReadInConfig()
}

func main() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}
```

```bash
# Build và dùng
go build -o devops-cli ./cmd/main.go

./devops-cli pods list -n production
./devops-cli deploy api 1.2.0 --namespace production --dry-run
./devops-cli deploy api 1.2.0 -n production --timeout 600
```

---

## 4. Ví Dụ Thực Tế: Kubernetes Pod Watcher

```go
package main

import (
    "context"
    "flag"
    "fmt"
    "log"
    "os"
    "path/filepath"
    "time"

    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/clientcmd"
    "k8s.io/client-go/util/homedir"
)

func main() {
    // Parse flags
    var kubeconfig *string
    var namespace *string
    
    if home := homedir.HomeDir(); home != "" {
        kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "kubeconfig path")
    } else {
        kubeconfig = flag.String("kubeconfig", "", "kubeconfig path")
    }
    namespace = flag.String("namespace", "default", "namespace to watch")
    flag.Parse()

    // Build K8s client
    config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
    if err != nil {
        log.Fatalf("Error building kubeconfig: %v", err)
    }

    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        log.Fatalf("Error creating kubernetes client: %v", err)
    }

    // Watch pods
    ctx := context.Background()
    fmt.Printf("Watching pods in namespace: %s\n", *namespace)

    for {
        pods, err := clientset.CoreV1().Pods(*namespace).List(ctx, metav1.ListOptions{})
        if err != nil {
            log.Printf("Error listing pods: %v", err)
            time.Sleep(10 * time.Second)
            continue
        }

        for _, pod := range pods.Items {
            status := string(pod.Status.Phase)
            restarts := getTotalRestarts(pod)

            if restarts > 5 || pod.Status.Phase == corev1.PodFailed {
                log.Printf("⚠️  ALERT: Pod %s/%s status=%s restarts=%d",
                    pod.Namespace, pod.Name, status, restarts)
            }
        }

        time.Sleep(30 * time.Second)
    }
}

func getTotalRestarts(pod corev1.Pod) int32 {
    var total int32
    for _, cs := range pod.Status.ContainerStatuses {
        total += cs.RestartCount
    }
    return total
}
```

```bash
# Cài deps
go get k8s.io/client-go@v0.29.2
go get k8s.io/api@v0.29.2
go mod tidy

# Build
go build -o pod-watcher ./cmd/watcher/main.go

# Cross-compile cho Linux (từ Mac)
GOOS=linux GOARCH=amd64 go build -o pod-watcher-linux ./cmd/watcher/main.go

# Chạy
./pod-watcher --namespace production
```

---

> **Tiếp theo: P3** - Testing, JSON/YAML, Configuration, Azure SDK cho Go
