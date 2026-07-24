---
markmap:
  title: "DevOps Intern Interview Guide"
  collapse: false
---

# 🎯 DEVOPS INTERN INTERVIEW GUIDE

## Theory
- Các chủ đề cốt lõi: version control, CI/CD, containers, orchestration, IaC, cloud, monitoring, security, automation.

## Practice
- Thực hành: templates câu trả lời, ví dụ pipelines, Dockerfile sample, Terraform backend snippet, và scripts kiểm thử nhanh.

## 1. Core Concepts

| Domain | Key Topics | Typical Interview Questions |
|--------|------------|-----------------------------|
| **Version Control** | Git basics, branching strategies, merge vs rebase, PR workflow | *Explain `git rebase` vs `git merge`.* |
| **CI/CD** | Pipelines, triggers, artifact handling, rollbacks, blue‑green / canary deployments | *Describe a typical CI/CD pipeline for a microservices app.* |
| **Containers** | Dockerfile anatomy, image layers, multi‑stage builds, container registries, runtime flags | *Why use a multi‑stage Dockerfile?* |
| **Orchestration** | Kubernetes fundamentals (Pods, Deployments, Services, Ingress, ConfigMaps, Secrets), Helm, Kustomize, K3s vs AKS, node scheduling, RBAC | *How does a `Deployment` ensure zero‑downtime updates?* |
| **Infrastructure as Code** | Terraform, Azure ARM/Bicep, Ansible, state management, modules, remote back‑ends | *Explain Terraform workspaces and why they’re useful.* |
| **Cloud Platforms** | Azure core services (VM, VNet, NSG, AKS, ACR, Key Vault, Monitor), IAM, networking, cost management | *What is a Managed Identity and how does it differ from a Service Principal?* |
| **Monitoring & Observability** | Azure Monitor, Log Analytics, Prometheus, Grafana, Application Insights, alerting, tracing (OpenTelemetry) | *How would you monitor a distributed microservice on AKS?* |
| **Security** | Secrets management, image scanning (Trivy, Defender), network policies, PodSecurityPolicies, least‑privilege IAM | *How to secure secrets in a CI pipeline?* |
| **Scripting / Automation** | Bash, PowerShell, Python/Go for tooling, CLI usage (az, kubectl, docker) | *Write a script to list all pods in `CrashLoopBackOff` state.* |
| **Testing** | Unit, integration, end‑to‑end, contract testing, test containers, CI test reporting | *What is the difference between unit and integration tests in a pipeline?* |
| **Troubleshooting** | Log analysis, `kubectl exec`, `kubectl debug`, `kubectl top`, network diagnostics, Helm rollback, diffing manifests | *Debug a failing Helm upgrade.* |


## 2. Frequently Asked Practical Tasks

1. **Create a GitHub Action that builds a Docker image and pushes to Azure Container Registry**
2. **Write a Terraform module that provisions an AKS cluster with Log Analytics enabled**
3. **Create a Helm chart for a simple Node.js app with configurable replica count**
4. **Implement a Bash script that monitors CPU usage on a Linux VM and sends an alert to Slack**
5. **Show how to use Azure Key Vault to inject secrets into a Kubernetes pod**
6. **Configure a Prometheus alert for pod restarts > 3 in 5 min**
7. **Explain how to migrate a legacy VM‑based app to a container‑first architecture**


## 3. Soft‑Skills & Culture Fit

- **Collaboration** – Working with developers, security, SREs.
- **Problem‑Solving** – Diagnose production incidents, root‑cause analysis.
- **Continuous Learning** – Staying up‑to‑date with cloud‑native tools.
- **Automation Mindset** – “Never manually do something that can be scripted.”


## 4. Quick Cheat‑Sheet

```bash
# Git shortcuts
git switch -c feature/xyz   # create & switch
git pull --rebase origin main

# Docker multi‑stage example
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp

FROM alpine:latest
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["myapp"]

# Terraform remote backend (Azure Storage)
terraform {
  backend "azurerm" {
    resource_group_name   = "tfstate-rg"
    storage_account_name  = "tfstatestorage001"
    container_name        = "tfstate"
    key                   = "devops/interview.tfstate"
  }
}

# Kubectl common one‑liners
kubectl get pods -A | grep CrashLoopBackOff
kubectl exec -it $POD -- sh
kubectl top nodes
```


> **Tip:** Tailor your answers with real‑world examples from the projects you’ve built (e.g., the Jenkins‑Azure integration you just documented).

## 5. CV-BASED ANSWERS

Phần này chuyển các điểm mạnh trong CV của bạn thành câu trả lời phỏng vấn. Mục tiêu là nói rõ: bạn đã làm gì, vì sao làm vậy, kết quả ra sao, và bạn học được gì.

### Q1. Giới thiệu bản thân theo hướng DevOps Intern

**Trả lời mẫu:**

> Em là sinh viên IT đang tập trung vào DevOps và cloud-native operations. Em đã tự xây dựng hai dự án chính: một nền tảng monitoring + CI/CD cho Django/PostgreSQL chạy trên Azure VM, và một dự án triển khai ứng dụng Voting App trên K3s Kubernetes cluster.
>
> Ở dự án đầu, em dùng Prometheus, Grafana, Node Exporter, PostgreSQL Exporter và Alertmanager để theo dõi hơn 20 metric, tạo 3 dashboard và 9 alert rule có cảnh báo Telegram. Em cũng dựng Jenkins pipeline 4 stage để build image, chuyển artifact, chờ approval và deploy lên Azure VM.
>
> Ở dự án thứ hai, em container hóa microservices, xây Jenkins pipeline 5 stage, push 3 image lên Docker Hub bằng commit tag, và triển khai lên K3s với Deployments, Services, Traefik Ingress, cùng Prometheus, Grafana và Loki để giám sát cluster.
>
> Điểm em muốn mang vào vị trí intern là tinh thần học nhanh, làm việc có hệ thống và thích tự động hóa thay vì thao tác thủ công.

### Q2. Vì sao em chọn DevOps?

**Trả lời mẫu:**

> Em thích DevOps vì đây là nơi em được làm việc ở giao điểm giữa code, hạ tầng và vận hành. Em không chỉ muốn app chạy được mà còn muốn quy trình build, test, deploy và monitoring được chuẩn hóa.
>
> Khi làm các dự án cá nhân, em thấy mỗi lần tự động hóa thành công đều giúp tiết kiệm nhiều công sức về sau: pipeline ngắn hơn, deploy lặp lại được, troubleshooting có log rõ hơn, và team có thể nhìn chung một bức tranh vận hành.
>
> Em chọn DevOps cũng vì em thích các bài toán mang tính hệ thống: cấu hình, tối ưu, phát hiện lỗi sớm và giữ cho dịch vụ ổn định.

### Q3. Hãy nói về dự án Monitoring & CI/CD Platform trên Azure VM

**Trả lời mẫu:**

> Dự án này là một nền tảng monitoring và CI/CD cho ứng dụng Django/PostgreSQL được triển khai trên Azure VM.
>
> Phần monitoring dùng Prometheus để scrape metric, Grafana để hiển thị dashboard, Node Exporter để lấy metric hạ tầng Linux, và PostgreSQL Exporter để theo dõi database. Em xây 3 dashboard riêng cho hạ tầng, backend Django và PostgreSQL/PostGIS.
>
> Phần CI/CD dùng Jenkins pipeline 4 stage gồm Build → Transfer → Approval → Deploy. Jenkins build Docker image, chuyển artifact an toàn, đợi bước phê duyệt trước khi production deploy, sau đó triển khai Docker Compose services lên Azure VM và chạy Django migrations.
>
> Em cũng viết 9 alert rule cho các tình huống như CPU cao, memory pressure, low disk space, instance down, HTTP 5xx, high latency, PostgreSQL downtime và excessive connections. Mục tiêu của em là không chỉ deploy được ứng dụng mà còn biết khi nào nó bắt đầu có dấu hiệu bất ổn.

### Q4. Tại sao em chọn Prometheus, Grafana, Alertmanager và Telegram?

**Trả lời mẫu:**

> Em chọn Prometheus vì mô hình pull phù hợp với môi trường cloud-native và dễ mở rộng theo target. Grafana cho em khả năng dựng dashboard trực quan, tách riêng từng góc nhìn: hạ tầng, app, database.
>
> Alertmanager giúp gom alert, route theo nhóm và tránh spam. Telegram được chọn vì dễ tạo channel nhận cảnh báo nhanh, phù hợp với mô hình project cá nhân và demo thực tế.
>
> Điểm quan trọng không phải là có alert, mà là alert phải có ngữ cảnh đủ rõ để biết nên xử lý ở tầng nào.

### Q5. Em đo lường “monitoring hiệu quả” như thế nào trong dự án?

**Trả lời mẫu:**

> Em không chỉ nhìn dashboard có đẹp hay không, mà nhìn vào số lượng metric hữu ích, số dashboard có mục đích rõ ràng, và khả năng phát hiện sự cố sớm.
>
> Trong dự án Azure VM, em theo dõi hơn 20 metric và tạo 3 dashboard để tránh trộn quá nhiều thông tin vào một chỗ. Em cũng xây 9 alert rule cho những nhóm lỗi có tác động thật như CPU, RAM, disk, HTTP error, database availability và connection saturation.
>
> Với em, monitoring tốt là monitoring giúp người vận hành trả lời được 3 câu: chuyện gì đang xảy ra, nó ảnh hưởng tới đâu, và cần xử lý gì tiếp theo.

### Q6. Hãy nói về pipeline Jenkins 4 stage của em

**Trả lời mẫu:**

> Pipeline của em gồm 4 stage: Build → Transfer → Approval → Deploy.
>
> Ở Build, Jenkins tạo Docker image từ source code. Ở Transfer, artifact được chuyển đến môi trường đích theo cách kiểm soát được. Ở Approval, em chèn bước chờ duyệt để không deploy production một cách mù quáng. Ở Deploy, Jenkins triển khai Docker Compose services và chạy Django migrations sau khi release thành công.
>
> Em chọn cấu trúc này vì nó phản ánh đúng thực tế vận hành: build xong chưa đủ, còn phải kiểm tra tính sẵn sàng, duyệt release và đảm bảo database migration không làm gián đoạn dịch vụ.

### Q7. Hãy nói về dự án K3s Voting App

**Trả lời mẫu:**

> Dự án thứ hai của em là triển khai ứng dụng Voting App gồm 5 service: Vote, Result, Worker, Redis và PostgreSQL trên K3s Kubernetes cluster.
>
> Em xây Jenkins pipeline 5 stage gồm Checkout → Docker Login → Build → Push → Deploy. Em tạo và đẩy 3 image ứng dụng là vote, result và worker lên Docker Hub với commit-based tag để truy vết version rõ ràng.
>
> Trên K8s, em triển khai Deployments, Services và Traefik Ingress để đảm bảo service discovery và truy cập bên ngoài. Em cũng thiết lập monitoring tập trung bằng Prometheus, Grafana và Loki, với 4 dashboard cho cluster health, Voting App analytics, PostgreSQL và Redis.

### Q8. Vì sao em chọn K3s thay vì K8s đầy đủ?

**Trả lời mẫu:**

> Em chọn K3s vì đây là lựa chọn phù hợp cho môi trường học tập, demo và lab cá nhân. Nó nhẹ hơn, dễ dựng hơn và vẫn giữ được các khái niệm cốt lõi của Kubernetes như Pod, Deployment, Service, Ingress và monitoring.
>
> Quan trọng hơn, em dùng K3s để chứng minh rằng em hiểu nguyên lý orchestration, chứ không chỉ chạy theo công cụ phức tạp.

### Q9. Em xử lý troubleshooting trong dự án K3s như thế nào?

**Trả lời mẫu:**

> Em thường đi từ symptom đến root cause. Ví dụ khi gặp vấn đề về connectivity hoặc Ingress, em sẽ kiểm tra Service selector, endpoint, Ingress routing, DNS và các log liên quan trước.
>
> Với service bị không reachable, em kiểm tra xem Pod có Running không, Service có endpoint đúng không, Traefik có route đúng host/path không, và workload có listen đúng port không.
>
> Cách em làm là loại trừ từng lớp: app, service, ingress, network, rồi mới đụng đến cluster-wide issues.

### Q10. Nếu interviewer hỏi “Điểm khác biệt lớn nhất giữa hai dự án của em là gì?”

**Trả lời mẫu:**

> Dự án Azure VM tập trung vào monitoring và CI/CD cho một ứng dụng monolith Django/PostgreSQL. Em muốn chứng minh rằng em có thể dựng được observability và release process có kiểm soát.
>
> Dự án K3s thì tập trung vào container orchestration và microservices. Ở đó em chứng minh rằng em biết đóng gói nhiều service, triển khai lên cluster, cấu hình Ingress, monitoring tập trung và xử lý luồng deploy theo image tag.
>
> Nói ngắn gọn, dự án đầu thiên về vận hành app trên VM, còn dự án hai thiên về cloud-native deployment trên Kubernetes.

### Q11. Nếu được hỏi vì sao em có thể phù hợp với vị trí intern?

**Trả lời mẫu:**

> Vì em đã chạm vào đúng các mảng mà một DevOps intern thường cần: Linux, Docker, Kubernetes, Jenkins, Prometheus, Grafana, Alertmanager, Terraform và Azure.
>
> Em chưa tự nhận là đã “biết hết”, nhưng em có lợi thế là đã tự làm end-to-end nhiều phần thực tế: build, deploy, monitor, alert và debug. Em cũng quen với việc đọc log, kiểm tra nguyên nhân và ghi chú lại cách xử lý để không lặp lỗi.

### Q12. Nếu được hỏi “Em sẽ cải thiện dự án của mình như thế nào?”

**Trả lời mẫu:**

> Nếu có thêm thời gian, em sẽ cải thiện theo 3 hướng. Một là chuẩn hóa IaC hơn nữa bằng Terraform cho toàn bộ hạ tầng. Hai là thêm test cho pipeline như smoke test và integration test rõ ràng hơn. Ba là hoàn thiện security hơn bằng secret manager, image scanning và policy kiểm soát quyền truy cập.
>
> Em cũng muốn bổ sung tracing để đi xa hơn mức metrics và logs, nhất là cho hệ thống có nhiều service.

### Q13. Hãy kể một vấn đề thực tế em đã debug

**Trả lời mẫu:**

> Trong quá trình làm K8s, em từng gặp vấn đề route hoặc service connectivity không ổn định. Thay vì đoán, em kiểm tra từng tầng: Pod status, labels/selectors của Service, endpoints, Ingress rules, rồi mới xem log của service và controller.
>
> Từ đó em rút ra rằng lỗi hạ tầng thường không nằm ở một chỗ duy nhất. Cần giữ quy trình debug có thứ tự để không bỏ sót lớp trung gian.

### Q14. Em muốn interviewer nhớ điều gì về CV của em?

**Trả lời mẫu:**

> Em muốn họ nhớ rằng em không chỉ liệt kê công cụ, mà đã thật sự dùng chúng để giải quyết bài toán. Em có hai project nổi bật, một trên Azure VM và một trên K3s, đều có CI/CD, monitoring và troubleshooting thực tế.
>
> Em có thể giải thích được pipeline, metric, dashboard, alert, ingress, service discovery và lý do chọn từng công cụ. Đó là điều em muốn thể hiện rõ nhất.

## 6. PROJECT DEEP-DIVE QUESTIONS

### Q1. Tại sao em dùng Docker Compose trong dự án Azure VM?

- Vì app Django/PostgreSQL chạy trên một VM đơn lẻ, Docker Compose giúp gom các service lại, cấu hình rõ ràng và triển khai lặp lại dễ hơn.
- Nó phù hợp với bối cảnh demo và intern project, nơi em cần tập trung vào automation và vận hành, không cần một orchestrator phức tạp.
- Compose cũng làm cho bước deploy gọn hơn và dễ gắn vào Jenkins pipeline.

### Q2. Tại sao em dùng commit-based tag cho image ở dự án K3s?

- Vì tag theo commit giúp truy vết chính xác version nào đang chạy trong cluster.
- Khi có lỗi, em biết ngay image nào được build từ commit nào.
- Cách này an toàn hơn `latest`, vì `latest` làm môi trường khó kiểm soát và rollback.

### Q3. Tại sao cần bước approval trước production?

- Vì production deploy cần kiểm soát thay đổi, nhất là khi có database migration hoặc thay đổi ảnh hưởng người dùng.
- Approval là “điểm dừng” để con người xác nhận trước khi đẩy release đi xa hơn.
- Đây là cách em thể hiện tư duy vận hành có trách nhiệm, không auto hóa mù quáng.

### Q4. Vì sao em tách dashboard theo hạ tầng, backend và database?

- Vì mỗi nhóm người xem cần một lớp thông tin khác nhau.
- Hạ tầng cần CPU, memory, disk, network.
- Backend cần latency, 5xx, request volume.
- Database cần connection, throughput, downtime và tài nguyên.
- Tách như vậy giúp đọc nhanh và giảm nhiễu.

### Q5. Nếu bị hỏi “Em học được gì từ hai dự án này?”

- Em học cách biến một ứng dụng đơn lẻ thành hệ thống có thể vận hành.
- Em hiểu rõ hơn mối liên hệ giữa build, release, monitoring và incident response.
- Em cũng học được rằng làm DevOps không phải chỉ viết script, mà là thiết kế luồng làm việc sao cho người khác và hệ thống đều dễ dùng.
