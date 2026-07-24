#!/bin/bash

# Tạo thư mục gốc mới cho lộ trình 60 video thực chiến
mkdir -p Lo_trinh_DevOps_Thuc_Chien_2026 && cd Lo_trinh_DevOps_Thuc_Chien_2026

# --- Phần 1: Tư duy DevOps & Cloud Basics ---
mkdir -p "Phan_01_Cloud_Basics"
touch "Phan_01_Cloud_Basics/V1_Day-1_Fundamentals_of_DevOps.docx" \
      "Phan_01_Cloud_Basics/V2_Day-2_Improve_SDLC_with_DevOps.docx" \
      "Phan_01_Cloud_Basics/V3_Day-1_Basics_of_Cloud_Computing.docx" \
      "Phan_01_Cloud_Basics/V4_Day-4_How_to_Create_Virtual_Machines.docx" \
      "Phan_01_Cloud_Basics/V5_Day-2_Getting_Started_With_Azure.docx"

# --- Phần 2: Nền tảng Mạng (Networking) ---
mkdir -p "Phan_02_Networking"
touch "Phan_02_Networking/V1_Networking_Concepts_are_Easy.docx" \
      "Phan_02_Networking/V2_OSI_Model_Simplified.docx" \
      "Phan_02_Networking/V3_Day-5_Azure_Virtual_Network_VNet.docx" \
      "Phan_02_Networking/V4_Day-6_Azure_Networking_Basic_to_Advanced.docx"

# --- Phần 3: Quản lý Dự án & Kỹ năng Môi trường ---
mkdir -p "Phan_03_Project_Management"
touch "Phan_03_Project_Management/V1_Day-22_Project_Management_tools.docx" \
      "Phan_03_Project_Management/V2_JIRA_Workflow_in_Real_Time.docx" \
      "Phan_03_Project_Management/V3_Day-27_Make_your_Windows_productive_WSL2.docx" \
      "Phan_03_Project_Management/V4_Day-24_DevOps_Resume_with_Projects.docx"

# --- Phần 4: Linux & Shell Scripting ---
mkdir -p "Phan_04_Linux_Shell_Scripting"
touch "Phan_04_Linux_Shell_Scripting/V1_Day-6_Linux_and_Shell_Scripting.docx" \
      "Phan_04_Linux_Shell_Scripting/V2_Shell_Scripting_Zero_2_Hero_Part-2.docx" \
      "Phan_04_Linux_Shell_Scripting/V3_Day-7_Live_AWS_Project_Shell_Scripting.docx" \
      "Phan_04_Linux_Shell_Scripting/V4_Day-8_Shell_Scripting_Project_GitHub_API.docx" \
      "Phan_04_Linux_Shell_Scripting/V5_Shell_Scripting_and_Linux_Interview_QnA.docx"

# --- Phần 5: Git & GitHub ---
mkdir -p "Phan_05_Git_GitHub"
touch "Phan_05_Git_GitHub/V1_Day-9_Git_and_GitHub_What_is_GIT.docx" \
      "Phan_05_Git_GitHub/V2_Day-10_Git_Branching_Strategy.docx" \
      "Phan_05_Git_GitHub/V3_Day-11_Git_Interview_QnA_and_Commands.docx" \
      "Phan_05_Git_GitHub/V4_GitHub_Actions_Self_Hosted_Runners.docx"

# --- Phần 6: Docker Cơ bản ---
mkdir -p "Phan_06_Docker_Basics"
touch "Phan_06_Docker_Basics/V1_Day-23_Introduction_to_Containers.docx" \
      "Phan_06_Docker_Basics/V2_Day-24_Docker_Zero_to_Hero_Part-1.docx" \
      "Phan_06_Docker_Basics/V3_Day-25_Docker_Containerization_for_Django.docx" \
      "Phan_06_Docker_Basics/V4_Day-26_Multi_Stage_Docker_Builds.docx" \
      "Phan_06_Docker_Basics/V5_Day-27_Docker_Volumes_and_Bind_Mounts.docx"

# --- Phần 7: Mạng Docker & Compose ---
mkdir -p "Phan_07_Docker_Networking_Compose"
touch "Phan_07_Docker_Networking_Compose/V1_Day-28_Docker_Networking.docx" \
      "Phan_07_Docker_Networking_Compose/V2_Docker_Compose_Beginner_Level_Guide.docx" \
      "Phan_07_Docker_Networking_Compose/V3_Day-29_Docker_Interview_Questions.docx"

# --- Phần 8: Infrastructure as Code (IaC) & Ansible ---
mkdir -p "Phan_08_IaC_Ansible"
touch "Phan_08_IaC_Ansible/V1_Day-16_Infrastructure_as_Code_Intro.docx" \
      "Phan_08_IaC_Ansible/V2_Day-17_Everything_about_Terraform.docx" \
      "Phan_08_IaC_Ansible/V3_Day-23_Terraform_for_Azure.docx" \
      "Phan_08_IaC_Ansible/V4_Day-14_Configuration_Management_With_Ansible.docx" \
      "Phan_08_IaC_Ansible/V5_Day-15_Ansible_Zero_to_Hero.docx"

# --- Phần 9: CI/CD Pipelines ---
mkdir -p "Phan_09_CICD_Pipelines"
touch "Phan_09_CICD_Pipelines/V1_Day-18_What_is_CICD.docx" \
      "Phan_09_CICD_Pipelines/V2_Day-19_Jenkins_ZERO_to_HERO.docx" \
      "Phan_09_CICD_Pipelines/V3_Ultimate_CICD_Pipeline_Jenkins_End_to_End.docx" \
      "Phan_09_CICD_Pipelines/V4_Day-20_GitHub_Actions_vs_Jenkins.docx" \
      "Phan_09_CICD_Pipelines/V5_Day-21_CICD_Interview_Questions.docx"

# --- Phần 10: Kubernetes Orchestration (Basics) ---
mkdir -p "Phan_10_K8s_Basics"
touch "Phan_10_K8s_Basics/V1_Day-30_Introduction_to_Kubernetes.docx" \
      "Phan_10_K8s_Basics/V2_Day-31_Kubernetes_Architecture.docx" \
      "Phan_10_K8s_Basics/V3_Day-32_Manage_Hundreds_of_K8s_clusters_KOPS.docx" \
      "Phan_10_K8s_Basics/V4_Day-33_Kubernetes_Pods.docx" \
      "Phan_10_K8s_Basics/V5_Day-34_Kubernetes_Deployment_and_ReplicaSets.docx"

# --- Phần 11: K8s Networking & Managed Services ---
mkdir -p "Phan_11_K8s_Networking_AKS"
touch "Phan_11_K8s_Networking_AKS/V1_Day-35_Kubernetes_Services.docx" \
      "Phan_11_K8s_Networking_AKS/V2_Day-38_Kubernetes_Ingress.docx" \
      "Phan_11_K8s_Networking_AKS/V3_Kubernetes_Service_Ingress_with_TLS.docx" \
      "Phan_11_K8s_Networking_AKS/V4_K8s_Gateway_API_Future_Standard.docx" \
      "Phan_11_K8s_Networking_AKS/V5_Day-16_AKS_vs_Self_Managed_Clusters.docx"

# --- Phần 12: K8s Advanced, Monitoring & GitOps ---
mkdir -p "Phan_12_K8s_Advanced_GitOps"
touch "Phan_12_K8s_Advanced_GitOps/V1_Day-41_ConfigMaps_and_Secrets.docx" \
      "Phan_12_K8s_Advanced_GitOps/V2_Introduction_to_K8s_RBAC.docx" \
      "Phan_12_K8s_Advanced_GitOps/V3_Realtime_DevOps_Project_Azure_ArgoCD.docx" \
      "Phan_12_K8s_Advanced_GitOps/V4_Day-19_Creating_Effective_Monitoring.docx" \
      "Phan_12_K8s_Advanced_GitOps/V5_Day-42_Kubernetes_Monitoring_Prom_Grafana.docx"

echo "------------------------------------------------------------"
echo "CHÚC MỪNG SẾP! Đã tạo xong bộ khung 12 phần (60 video)."
echo "Lộ trình: Shell Script -> Docker -> K8s -> CI/CD đã sẵn sàng."
echo "------------------------------------------------------------"