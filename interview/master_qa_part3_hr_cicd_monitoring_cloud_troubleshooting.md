# 🚀 BỘ CÂU HỎI PHỎNG VẤN DEVOPS THỰC TẾ (PHẦN 3: HR, JENKINS, MONITORING, AZURE, TROUBLESHOOTING)
*Mức độ: Intern, Fresher, Junior*

Tài liệu này bổ sung cho:
- [Phần 1: Linux, Bash, Git, Network](master_qa_part1_linux_git_network.md)
- [Phần 2: Docker & Kubernetes](master_qa_part2_docker_k8s.md)

Mục tiêu của phần này là hoàn thiện các chủ đề còn thiếu trong bản outline gốc: HR/Behavioral, Jenkins/CI-CD, Monitoring, Azure/Cloud, Security và Troubleshooting.

Một vài khái niệm cắt ngang như DNS, SSH hoặc Load Balancer đã được giữ ở đúng bối cảnh hỏi đáp của chúng. Khi một thuật ngữ xuất hiện ở nhiều phần, mình ưu tiên giải thích theo ngữ cảnh khác nhau thay vì lặp nguyên văn.

---

## 🤝 PHẦN 1: HR & BEHAVIORAL

**1. Giới thiệu bản thân.**
* **Trả lời:** Em là sinh viên/ứng viên quan tâm DevOps, có nền tảng Linux, Git, Docker và đang rèn kỹ năng tự động hóa, triển khai và giám sát hệ thống. Em thích cách DevOps giúp đội ngũ giao hàng nhanh hơn nhưng vẫn giữ ổn định.

**2. Tại sao em chọn DevOps?**
* **Trả lời:** Vì DevOps cho em nhìn thấy toàn bộ vòng đời phần mềm, từ code đến vận hành. Em thích kết hợp kỹ thuật hệ thống, tự động hóa và tối ưu quy trình.

**3. Tại sao không chọn Backend?**
* **Trả lời:** Em vẫn thấy backend rất quan trọng, nhưng em hợp hơn với hướng hạ tầng, CI/CD, cloud và automation. DevOps cho em không gian để làm việc với nhiều lớp hệ thống hơn.

**4. Tại sao muốn làm DevOps?**
* **Trả lời:** Vì em thích giảm thao tác thủ công, chuẩn hóa quy trình và làm hệ thống ổn định hơn. Em thấy giá trị rõ nhất của DevOps nằm ở khả năng hỗ trợ cả dev lẫn ops.

**5. Em biết gì về công ty?**
* **Trả lời:** Em tìm hiểu về lĩnh vực công ty, sản phẩm/dịch vụ, quy mô team kỹ thuật và công nghệ đang dùng. Em cũng quan tâm cách công ty làm việc, môi trường học hỏi và văn hóa phối hợp.

**6. Tại sao em ứng tuyển vào công ty chúng tôi?**
* **Trả lời:** Vì công ty có bài toán thực tế, quy trình kỹ thuật rõ ràng và cơ hội học từ người có kinh nghiệm. Em muốn được đóng góp vào vận hành ổn định và học cách làm việc chuyên nghiệp.

**7. Điểm mạnh của em là gì?**
* **Trả lời:** Em học nhanh, chịu khó đào sâu vấn đề và khá cẩn thận khi làm việc với hệ thống. Em cũng chủ động ghi lại kiến thức để tránh lặp lỗi.

**8. Điểm yếu của em là gì?**
* **Trả lời:** Em đôi lúc muốn kiểm tra quá nhiều trước khi chốt một hướng xử lý. Em đang cải thiện bằng cách ưu tiên mức độ ảnh hưởng và ra quyết định theo dữ liệu.

**9. Thành tựu lớn nhất của em?**
* **Trả lời:** Là một dự án hoặc bài tập mà em tự triển khai từ đầu đến cuối, ví dụ dựng CI/CD, container hóa ứng dụng hoặc tự động hóa một tác vụ lặp lại.

**10. Thất bại lớn nhất?**
* **Trả lời:** Một lần em xử lý chưa tốt vì chưa kiểm tra đủ ngữ cảnh, dẫn đến sửa chậm hơn dự kiến. Từ đó em học cách xác định giả thuyết, kiểm tra log và rollback sớm hơn.

**11. Dự án em tự hào nhất?**
* **Trả lời:** Dự án mà em có thể nói rõ mục tiêu, phần em làm, kết quả đo được và bài học rút ra. Nên ưu tiên dự án có yếu tố automation hoặc hạ tầng.

**12. Em làm gì khi gặp bug?**
* **Trả lời:** Em tái hiện lỗi, đọc log, khoanh vùng thay đổi gần nhất và kiểm tra theo tầng từ ngoài vào trong. Nếu cần, em chia nhỏ vấn đề để xác định nguyên nhân gốc.

**13. Khi không biết một công nghệ mới em làm sao?**
* **Trả lời:** Em đọc tài liệu chính thức, làm một demo nhỏ, rồi kiểm tra bằng thực hành. Nếu vẫn chưa rõ, em hỏi người có kinh nghiệm bằng câu hỏi cụ thể.

**14. Em làm việc nhóm thế nào?**
* **Trả lời:** Em ưu tiên giao tiếp rõ ràng, cập nhật tiến độ sớm và không giấu vấn đề. Khi làm chung, em cố gắng viết thứ người khác có thể đọc và tiếp tục được.

**15. Em giải quyết mâu thuẫn ra sao?**
* **Trả lời:** Em quay về dữ kiện và mục tiêu chung thay vì tranh luận cảm tính. Nếu có bất đồng, em đề xuất thử nghiệm hoặc tiêu chí đo để chọn hướng đúng hơn.

**16. Em có thể làm OT không?**
* **Trả lời:** Có, nếu công việc thật sự cần và có kế hoạch rõ ràng. Em vẫn ưu tiên cách làm bền vững để tránh OT trở thành thói quen.

**17. Mục tiêu 3 năm tới?**
* **Trả lời:** Em muốn vững nền tảng Linux, cloud, CI/CD và có thể tự xử lý các hệ thống nhỏ đến vừa. Xa hơn, em muốn trở thành người có thể thiết kế và vận hành hệ thống đáng tin cậy.

**18. Mức lương mong muốn?**
* **Trả lời:** Em ưu tiên cơ hội học đúng và môi trường phù hợp, mức lương em mong muốn có thể trao đổi theo mặt bằng thị trường và scope công việc.

**19. Em còn đi học không?**
* **Trả lời:** Nếu còn học, em có thể nêu lịch học rõ ràng và khả năng sắp xếp. Nếu đã tốt nghiệp, em nói rõ tình trạng sẵn sàng đi làm.

**20. Khi nào có thể đi làm?**
* **Trả lời:** Em có thể đi làm từ thời điểm phù hợp với lịch bàn giao/học tập hiện tại, và em sẽ chủ động sắp xếp để vào việc sớm nhất có thể.

**21. Vì sao chúng tôi nên tuyển em?**
* **Trả lời:** Vì em có tinh thần học nhanh, làm cẩn thận và phù hợp với các việc nền tảng như automation, monitoring, troubleshooting. Em cũng có thái độ cầu thị và chịu nhận phản hồi.

**22. Em có câu hỏi gì cho công ty?**
* **Trả lời:** Em có thể hỏi về stack kỹ thuật, cách team xử lý incident, lộ trình học việc, KPI của intern/junior và quy trình review công việc.

**23. Em học DevOps bằng cách nào?**
* **Trả lời:** Em học từ tài liệu chính thức, lab thực hành, ghi chú lại từng lỗi gặp phải và tự dựng mini-project. Em ưu tiên học theo vòng lặp đọc - làm - kiểm tra - ghi nhớ.

**24. Em có chứng chỉ Cloud nào không?**
* **Trả lời:** Nếu có thì nêu đúng tên chứng chỉ và giá trị thực tế của nó. Nếu chưa có, em nên nói đang học và tập trung vào năng lực thực hành.

**25. Em đánh giá bản thân bao nhiêu điểm?**
* **Trả lời:** Em thường tránh chấm điểm quá cảm tính, thay vào đó nói rõ điểm mạnh, điểm đang cải thiện và ví dụ chứng minh. Cách này thật hơn và dễ tin hơn.

---

## 🧪 PHẦN 2: JENKINS & CI/CD

**1. Jenkins là gì?**
* **Trả lời:** Jenkins là công cụ tự động hóa CI/CD phổ biến, dùng để build, test, scan và deploy ứng dụng theo pipeline.

**2. Jenkins Agent?**
* **Trả lời:** Là máy hoặc container thực thi job thay cho controller, giúp tách tải build khỏi máy Jenkins chính.

**3. Pipeline?**
* **Trả lời:** Là luồng các bước tự động hóa từ checkout, build, test đến deploy.

**4. Declarative Pipeline?**
* **Trả lời:** Là kiểu pipeline có cấu trúc rõ ràng, dễ đọc, dễ chuẩn hóa và thường được khuyến nghị cho team.

**5. Scripted Pipeline?**
* **Trả lời:** Linh hoạt hơn vì viết gần với Groovy thuần, nhưng khó đọc và khó bảo trì hơn declarative.

**6. Stage?**
* **Trả lời:** Là một chặng lớn trong pipeline, ví dụ Build, Test, Deploy.

**7. Step?**
* **Trả lời:** Là một hành động nhỏ bên trong stage, ví dụ `sh`, `archiveArtifacts`, `withCredentials`.

**8. Agent any?**
* **Trả lời:** Nghĩa là stage hoặc pipeline có thể chạy trên bất kỳ agent nào còn trống.

**9. Credentials?**
* **Trả lời:** Là cơ chế lưu thông tin nhạy cảm an toàn hơn hardcode, ví dụ username/password, SSH key, token.

**10. Webhook?**
* **Trả lời:** Là cơ chế để Git server chủ động báo Jenkins khi có push hoặc merge mới.

**11. Poll SCM?**
* **Trả lời:** Là Jenkins tự định kỳ đi kiểm tra source code có thay đổi không, rồi mới chạy job.

**12. Git Checkout?**
* **Trả lời:** Là bước kéo source code về workspace của Jenkins để bắt đầu build.

**13. Docker Build?**
* **Trả lời:** Là bước tạo Docker image từ Dockerfile trong pipeline.

**14. Docker Push?**
* **Trả lời:** Là đẩy image đã build lên registry như Docker Hub, Harbor, ACR hoặc ECR.

**15. Approval Stage?**
* **Trả lời:** Là bước chờ người duyệt trước khi deploy sang môi trường nhạy cảm như staging/prod.

**16. Deploy Stage?**
* **Trả lời:** Là bước triển khai artifact hoặc image mới lên môi trường đích.

**17. Rollback?**
* **Trả lời:** Là quay lại phiên bản trước khi bản mới gây lỗi.

**18. Jenkinsfile?**
* **Trả lời:** Là file khai báo pipeline được lưu cùng source code, giúp pipeline có thể version control.

**19. Environment?**
* **Trả lời:** Là biến môi trường dùng trong pipeline, ví dụ image tag, namespace, registry.

**20. Post Block?**
* **Trả lời:** Là phần chạy sau pipeline hoặc sau stage, dùng để cleanup, notify hoặc archive log.

**21. Build Trigger?**
* **Trả lời:** Là điều kiện kích hoạt job như webhook, schedule, manual, hoặc upstream job.

**22. Artifact?**
* **Trả lời:** Là file đầu ra của build, ví dụ jar, war, binary, tarball hoặc report test.

**23. Workspace?**
* **Trả lời:** Là thư mục làm việc tạm của job trên agent.

**24. Build Number?**
* **Trả lời:** Là số thứ tự mỗi lần build, dùng để trace lịch sử và version hóa artifact.

**25. Blue Ocean?**
* **Trả lời:** Là giao diện Jenkins hiện đại, trực quan hơn classic UI.

**26. Plugin?**
* **Trả lời:** Là gói mở rộng chức năng cho Jenkins, ví dụ Git, Docker, Blue Ocean, Kubernetes plugin.

**27. Shared Library?**
* **Trả lời:** Là thư viện dùng chung cho nhiều Jenkinsfile để tránh copy-paste logic.

**28. Secret?**
* **Trả lời:** Là dữ liệu nhạy cảm như token, password, private key cần được quản lý an toàn.

**29. SSH Agent?**
* **Trả lời:** Là cơ chế nạp SSH key vào môi trường pipeline để pull/push qua SSH an toàn.

**30. `docker save`?**
* **Trả lời:** Xuất image ra file tar để chuyển giữa các máy mà không cần registry.

**31. `docker load`?**
* **Trả lời:** Nạp image từ file tar đã export trước đó.

**32. Pipeline Failure?**
* **Trả lời:** Là pipeline bị dừng do bước nào đó lỗi; cần đọc log, xác định stage lỗi và kiểm tra lại input, credential hoặc môi trường.

**33. Retry?**
* **Trả lời:** Là cho phép chạy lại một bước khi lỗi tạm thời, ví dụ network chập chờn.

**34. Timeout?**
* **Trả lời:** Là giới hạn thời gian tối đa cho job hoặc step để tránh treo vô hạn.

**35. Parallel Stage?**
* **Trả lời:** Là chạy nhiều nhánh công việc song song để rút ngắn thời gian pipeline.

**36. Pipeline Parameter?**
* **Trả lời:** Là tham số đầu vào cho job, ví dụ branch name, environment hoặc image tag.

**37. Agent Label?**
* **Trả lời:** Là nhãn gắn cho agent để Jenkins chọn đúng máy có tool hoặc runtime cần thiết.

**38. Master-Agent?**
* **Trả lời:** Là mô hình controller điều phối và agent thực thi, giúp tách phần quản lý khỏi phần chạy job.

**39. Continuous Integration?**
* **Trả lời:** Là thực hành merge code thường xuyên và tự động build/test để phát hiện lỗi sớm.

**40. Continuous Delivery?**
* **Trả lời:** Là mọi thay đổi sau khi qua pipeline đều sẵn sàng deploy, nhưng vẫn cần bước duyệt tay trước production.

**41. Continuous Deployment?**
* **Trả lời:** Là mỗi thay đổi đạt chuẩn sẽ tự động deploy luôn sang môi trường đích.

**42. Git Flow?**
* **Trả lời:** Là chiến lược branching có `main`, `develop`, `feature`, `release`, `hotfix`.

**43. Branch Strategy?**
* **Trả lời:** Là quy ước dùng nhánh theo mục đích để tránh xung đột và dễ review, ví dụ feature branch cho từng task.

**44. Release Pipeline?**
* **Trả lời:** Là pipeline dành riêng cho phát hành, thường có test, scan, approval và deploy.

**45. Canary Deployment?**
* **Trả lời:** Là triển khai một phần nhỏ traffic sang version mới trước, nếu ổn mới tăng dần tỉ lệ.

---

## 📈 PHẦN 3: MONITORING

**1. Prometheus?**
* **Trả lời:** Là hệ thống thu thập metric và lưu theo dạng time series rất phổ biến trong cloud-native.

**2. Metric?**
* **Trả lời:** Là giá trị đo được theo thời gian, ví dụ CPU usage, request count, latency.

**3. Time Series?**
* **Trả lời:** Là dữ liệu có timestamp, được lưu thành chuỗi theo thời gian.

**4. Exporter?**
* **Trả lời:** Là thành phần chuyển metric nội bộ của hệ thống thành format Prometheus có thể scrape.

**5. Node Exporter?**
* **Trả lời:** Là exporter phổ biến để lấy metric cấp máy như CPU, RAM, disk, network.

**6. PostgreSQL Exporter?**
* **Trả lời:** Là exporter thu metric từ PostgreSQL như connection, replication, queries.

**7. Django Metrics?**
* **Trả lời:** Là metric ứng dụng Django như request count, latency, error rate, thường expose qua Prometheus client library.

**8. Prometheus Pull Model?**
* **Trả lời:** Prometheus chủ động đi scrape metric từ target theo chu kỳ.

**9. Pushgateway?**
* **Trả lời:** Là điểm nhận metric push từ job ngắn hạn, sau đó Prometheus sẽ pull từ Pushgateway.

**10. PromQL?**
* **Trả lời:** Là ngôn ngữ truy vấn metric của Prometheus.

**11. Grafana?**
* **Trả lời:** Là công cụ tạo dashboard để trực quan hóa metric, log và trace.

**12. Dashboard?**
* **Trả lời:** Là màn hình tổng hợp các chỉ số quan trọng để theo dõi hệ thống.

**13. Panel?**
* **Trả lời:** Là một khối biểu đồ hoặc bảng trong dashboard.

**14. Variable?**
* **Trả lời:** Là biến dùng để filter dashboard theo cluster, namespace, instance, service.

**15. Alert?**
* **Trả lời:** Là cảnh báo được kích hoạt khi metric vượt ngưỡng hoặc có trạng thái bất thường.

**16. Alert Rule?**
* **Trả lời:** Là điều kiện để sinh alert, ví dụ CPU > 80% trong 5 phút.

**17. Alertmanager?**
* **Trả lời:** Là thành phần nhận alert từ Prometheus, grouping, dedup và routing đến kênh thông báo.

**18. Telegram Integration?**
* **Trả lời:** Là cấu hình Alertmanager gửi cảnh báo vào Telegram bot hoặc group.

**19. Route?**
* **Trả lời:** Là quy tắc định tuyến alert đến receiver phù hợp.

**20. Receiver?**
* **Trả lời:** Là đích nhận alert như email, Slack, Telegram, webhook.

**21. Group Interval?**
* **Trả lời:** Là khoảng thời gian Alertmanager gom nhiều alert cùng nhóm trước khi gửi.

**22. Repeat Interval?**
* **Trả lời:** Là thời gian chờ trước khi nhắc lại một alert chưa được xử lý.

**23. Silence?**
* **Trả lời:** Là cách tạm tắt cảnh báo trong một khoảng thời gian, thường dùng khi bảo trì.

**24. Loki?**
* **Trả lời:** Là hệ thống thu thập và truy vấn log, thường đi cùng Grafana.

**25. Log?**
* **Trả lời:** Là bản ghi sự kiện của hệ thống hoặc ứng dụng, dùng để debug và audit.

**26. LogQL?**
* **Trả lời:** Là ngôn ngữ truy vấn log của Loki.

**27. Four Golden Signals?**
* **Trả lời:** Là 4 chỉ số cốt lõi: latency, traffic, errors, saturation.

**28. RED Method?**
* **Trả lời:** Áp dụng cho service: Rate, Errors, Duration.

**29. USE Method?**
* **Trả lời:** Áp dụng cho hạ tầng: Utilization, Saturation, Errors.

**30. MTTD?**
* **Trả lời:** Mean Time To Detect, thời gian trung bình để phát hiện sự cố.

**31. MTTR?**
* **Trả lời:** Mean Time To Recover/Repair, thời gian trung bình để khôi phục dịch vụ.

**32. CPU Usage?**
* **Trả lời:** Là mức sử dụng CPU của hệ thống hoặc container theo thời gian.

**33. Memory Usage?**
* **Trả lời:** Là mức sử dụng RAM, cần chú ý leak và OOM.

**34. Disk Usage?**
* **Trả lời:** Là mức sử dụng dung lượng ổ đĩa, gồm data và log.

**35. Filesystem?**
* **Trả lời:** Là tình trạng của phân vùng đĩa, gồm dung lượng, inode và mount point.

**36. Network Traffic?**
* **Trả lời:** Là lưu lượng mạng vào/ra của host hoặc service.

**37. HTTP Latency?**
* **Trả lời:** Là thời gian xử lý request HTTP, thường theo percentile như p95, p99.

**38. HTTP 5xx?**
* **Trả lời:** Là lỗi phía server, thường cho biết service đang có vấn đề.

**39. Database Connection?**
* **Trả lời:** Là số kết nối tới DB; tăng đột biến có thể gây quá tải.

**40. PostgreSQL Down?**
* **Trả lời:** Là trạng thái PostgreSQL không phản hồi hoặc không accept connection, cần kiểm tra service, disk, memory, log.

**41. Instance Down?**
* **Trả lời:** Là máy hoặc pod không còn reachable, thường cần kiểm tra health check, node status, network và process.

**42. Dashboard Design?**
* **Trả lời:** Nên đặt chỉ số quan trọng nhất ở đầu, nhóm theo service, tránh quá nhiều panel và dùng ngưỡng màu rõ ràng.

**43. Alert Fatigue?**
* **Trả lời:** Là tình trạng bị quá nhiều alert gây mệt mỏi và dễ bỏ sót cảnh báo thật.

**44. High Cardinality?**
* **Trả lời:** Là metric có quá nhiều label value khác nhau, làm Prometheus tốn tài nguyên và khó truy vấn.

**45. Recording Rule?**
* **Trả lời:** Là rule tính sẵn biểu thức PromQL phức tạp và lưu kết quả thành metric mới để query nhanh hơn.

---

## ☁️ PHẦN 4: AZURE & CLOUD

**1. Azure VM**
* **Trả lời:** Là máy ảo chạy trên Azure, tương đương server vật lý được quản lý bởi cloud.

**2. Virtual Network**
* **Trả lời:** Là mạng riêng ảo trong Azure để cô lập tài nguyên và định tuyến nội bộ.

**3. NSG**
* **Trả lời:** Network Security Group là firewall cấp subnet hoặc NIC.

**4. Public IP**
* **Trả lời:** Là địa chỉ IP public gắn cho tài nguyên Azure để truy cập từ Internet.

**5. Availability Set**
* **Trả lời:** Là cơ chế phân tán VM qua fault domain và update domain để tăng tính sẵn sàng.

**6. Availability Zone**
* **Trả lời:** Là vùng vật lý độc lập trong cùng một region để chống lỗi datacenter.

**7. Managed Disk**
* **Trả lời:** Là ổ đĩa do Azure quản lý, dễ mở rộng và snapshot.

**8. Storage Account**
* **Trả lời:** Là dịch vụ lưu trữ tổng quát cho blob, file, queue và table.

**9. Azure Monitor**
* **Trả lời:** Là nền tảng giám sát tài nguyên, metric và log trên Azure.

**10. Azure CLI**
* **Trả lời:** Là công cụ dòng lệnh để quản lý tài nguyên Azure.

**11. SSH Key**
* **Trả lời:** Là cặp key dùng để đăng nhập VM an toàn không cần password. Xem thêm phần 1 nếu cần ôn sâu về SSH ở mức hệ thống.

**12. VM Size**
* **Trả lời:** Là cấu hình CPU, RAM, disk và network của VM.

**13. Scale Set**
* **Trả lời:** Là nhóm VM có thể scale tự động theo nhu cầu.

**14. Azure DNS**
* **Trả lời:** Là dịch vụ quản lý DNS trên Azure, dùng để host và phân giải tên miền trong hệ sinh thái Azure.

**15. Azure Load Balancer**
* **Trả lời:** Là thành phần phân phối traffic cấp mạng đến nhiều backend VM hoặc service. Khác với phần networking ở file 1, ở đây đang nói về tài nguyên của Azure.

**16. Terraform là gì?**
* **Trả lời:** Terraform là công cụ IaC để khai báo và quản lý hạ tầng bằng code.

**17. Terraform State?**
* **Trả lời:** Là file ghi nhận trạng thái hạ tầng hiện tại để Terraform biết cần thay đổi gì.

**18. Provider?**
* **Trả lời:** Là plugin cho Terraform để làm việc với Azure, AWS, GCP hoặc service khác.

**19. Resource?**
* **Trả lời:** Là một đối tượng hạ tầng cụ thể như VM, VNet, NSG.

**20. Module?**
* **Trả lời:** Là gói cấu hình Terraform tái sử dụng được.

**21. Plan?**
* **Trả lời:** Là bước xem trước Terraform sẽ thay đổi gì trước khi áp dụng.

**22. Apply?**
* **Trả lời:** Là bước thực thi thay đổi lên hạ tầng thật.

**23. Destroy?**
* **Trả lời:** Là xóa hạ tầng do Terraform quản lý.

**24. Remote Backend?**
* **Trả lời:** Là nơi lưu state từ xa, ví dụ Azure Storage, giúp tránh xung đột state local.

**25. Drift?**
* **Trả lời:** Là tình trạng hạ tầng thực tế bị lệch so với cấu hình trong code.

---

## 🔐 PHẦN 5: SECURITY & DEVSECOPS

**1. Principle of Least Privilege là gì?**
* **Trả lời:** Là chỉ cấp đúng quyền tối thiểu cần thiết cho người dùng, service account hoặc container để giảm rủi ro.

**2. Secrets nên được lưu ở đâu?**
* **Trả lời:** Không hardcode trong code hay image. Nên dùng Secret Manager, Key Vault, Vault hoặc cơ chế secret của nền tảng.

**3. Image scanning là gì?**
* **Trả lời:** Là kiểm tra image để tìm CVE, package lỗi thời hoặc cấu hình nguy hiểm trước khi deploy.

**4. Static code scan là gì?**
* **Trả lời:** Là quét source code hoặc manifest để tìm lỗi bảo mật, pattern nguy hiểm và sai cấu hình trước khi chạy.

**5. Runtime security là gì?**
* **Trả lời:** Là giám sát hành vi thực thi thật của container, process hoặc node để phát hiện hành vi bất thường.

**6. RBAC trong CI/CD nên chú ý gì?**
* **Trả lời:** Mỗi pipeline, service account hoặc user chỉ nên có quyền đủ dùng cho đúng môi trường và đúng tài nguyên.

**7. Vì sao không nên dùng `latest` cho image production?**
* **Trả lời:** Vì tag này mutable, dễ làm môi trường thay đổi ngoài ý muốn và khó rollback chính xác.

**8. Supply chain security là gì?**
* **Trả lời:** Là bảo vệ toàn bộ chuỗi từ source, dependency, build, registry đến deploy để tránh chèn mã độc hoặc artifact giả.

**9. SBOM là gì?**
* **Trả lời:** Software Bill of Materials là danh sách thành phần phần mềm bên trong một artifact hoặc image.

**10. Tại sao nên ký image hoặc artifact?**
* **Trả lời:** Để xác thực artifact đến từ nguồn tin cậy và không bị sửa đổi ngoài ý muốn.

---

## 🧯 PHẦN 6: TROUBLESHOOTING

**1. Jenkins build fail.**
* **Trả lời:** Xem console log, xác định stage lỗi, kiểm tra dependency, credential, agent và network.

**2. Docker build fail.**
* **Trả lời:** Kiểm tra Dockerfile, context build, base image và lỗi trong bước `RUN`.

**3. Docker push fail.**
* **Trả lời:** Thường do login registry, tag sai hoặc quyền không đủ.

**4. Docker pull fail.**
* **Trả lời:** Kiểm tra tên image, tag, network và quyền truy cập registry.

**5. Container restart liên tục.**
* **Trả lời:** Xem `docker logs`, `docker inspect` và nguyên nhân app exit ngay sau khi start.

**6. Pod Pending.**
* **Trả lời:** Thường do thiếu resource, sai node selector, thiếu PV hoặc scheduler chưa đặt được pod.

**7. Pod CrashLoopBackOff.**
* **Trả lời:** Xem logs, logs `--previous`, probe, config và exit code.

**8. ImagePullBackOff.**
* **Trả lời:** Kiểm tra image name/tag, registry auth và kết nối mạng của node.

**9. Ingress không hoạt động.**
* **Trả lời:** Kiểm tra Ingress Controller, class, service backend, DNS và TLS.

**10. Service không truy cập được.**
* **Trả lời:** Kiểm tra selector, endpoint, port mapping và network policy.

**11. DNS lỗi.**
* **Trả lời:** Kiểm tra CoreDNS, resolv.conf, service name và network policy.

**12. Prometheus scrape fail.**
* **Trả lời:** Kiểm tra target, service discovery, endpoint `/metrics` và network.

**13. Grafana không có dữ liệu.**
* **Trả lời:** Kiểm tra data source, query, time range và metric nguồn.

**14. Alert không gửi Telegram.**
* **Trả lời:** Kiểm tra Alertmanager config, route, receiver, token bot và network outbound.

**15. PostgreSQL down.**
* **Trả lời:** Kiểm tra service status, disk, memory, logs, replication và connection count.

**16. CPU 100%.**
* **Trả lời:** Xác định process tiêu thụ bằng top/htop, container stats hoặc metric dashboard.

**17. RAM đầy.**
* **Trả lời:** Tìm process leak, xem OOMKilled, giới hạn memory và cleanup cache nếu cần.

**18. Disk full.**
* **Trả lời:** Kiểm tra log, temporary file, image/container rác và inode.

**19. Docker daemon chết.**
* **Trả lời:** Xem `journalctl -u docker.service`, kiểm tra disk, config và runtime.

**20. Jenkins Agent offline.**
* **Trả lời:** Kiểm tra kết nối SSH/JNLP, label, credential và tài nguyên máy agent.

**21. SSH không kết nối được.**
* **Trả lời:** Kiểm tra IP, port 22, firewall, key, user và service sshd.

**22. Kubernetes rollout thất bại.**
* **Trả lời:** Kiểm tra `kubectl rollout status`, events, image, probe và resource.

**23. Deployment không update image.**
* **Trả lời:** Có thể do dùng tag mutable như `latest`; nên đổi tag rõ ràng hoặc rollout restart.

**24. PVC không mount được.**
* **Trả lời:** Kiểm tra StorageClass, PV binding, access mode và quyền của volume.

**25. Secret không đọc được.**
* **Trả lời:** Kiểm tra namespace, key name, RBAC và cách mount hoặc reference secret.

**26. ConfigMap không cập nhật.**
* **Trả lời:** Pod thường không tự reload; cần restart deployment hoặc app phải hỗ trợ reload.

**27. Pod không resolve DNS.**
* **Trả lời:** Kiểm tra CoreDNS, `/etc/resolv.conf`, network policy và service name.

**28. HTTP 502 Bad Gateway.**
* **Trả lời:** Proxy không nói chuyện được với upstream, thường do app chết, sai port hoặc timeout.

**29. HTTP 503 Service Unavailable.**
* **Trả lời:** Service chưa sẵn sàng hoặc không còn backend healthy.

**30. Load Balancer lỗi.**
* **Trả lời:** Kiểm tra health probe, backend pool, port và security rule.

**31. Container không expose port.**
* **Trả lời:** Kiểm tra app có listen đúng port, Dockerfile `EXPOSE`, và mapping `-p`.

**32. Reverse Proxy lỗi.**
* **Trả lời:** Kiểm tra upstream, DNS, TLS, header và timeout cấu hình.

**33. Database connection timeout.**
* **Trả lời:** Kiểm tra network, firewall, pool kết nối, DNS và tình trạng DB.

**34. Redis mất kết nối.**
* **Trả lời:** Kiểm tra service, port, password, network và trạng thái Redis.

**35. Network latency cao.**
* **Trả lời:** Kiểm tra packet loss, route, DNS, congestion và tài nguyên node.

**36. Alert gửi quá nhiều (alert storm).**
* **Trả lời:** Giảm nhiễu bằng grouping, inhibit, threshold hợp lý và recording rule.

**37. Rollback deployment.**
* **Trả lời:** Dùng `kubectl rollout undo` hoặc quay về image tag cũ đã ổn định.

**38. Node NotReady.**
* **Trả lời:** Kiểm tra kubelet, network, disk pressure, memory pressure và runtime.

**39. etcd đầy.**
* **Trả lời:** Xóa object không dùng, kiểm tra retention, backup và dung lượng disk của control plane.

**40. Kubernetes cluster không tạo được Pod.**
* **Trả lời:** Kiểm tra scheduler, quota, resource, events, taint/toleration, PVC và image pull.

---

## Ghi chú

Các phần Linux, Bash, Git, Networking, Docker và Kubernetes đã có bản hỏi đáp chi tiết ở Phần 1 và Phần 2. Phần 3 này chủ yếu lấp các mảng còn thiếu để bộ tài liệu thành một bộ ôn tập DevOps Intern trọn vẹn hơn.
