# SDN Topology Automation Script

Script for provisioning SDN network topologies on AWS using Terraform, Ansible, Docker, and Containernet.

---



## Prerequisites

- Active AWS Academy account with active Lab
- Linux terminal with root permissions

---

## How to Use

**1.** Clone the repository:
```sh
git clone https://github.com/vitorreiel/cloud-sdn-setup.git
cd cloud-sdn-setup
```

**2.** Start the Lab in AWS Academy and obtain your credentials (AWS Details > AWS CLI > Show)

**3.** Edit the `aws_access` file with your credentials:
```sh
nano aws_access
```

**4.** Execute the script:
```sh
./start.sh
```

---

#### Dataset and Analysis
Comparative analysis data available at: [dataset-sdn-setup](https://github.com/vitorreiel/dataset-sdn-setup.git)

---

![Development Badge](http://img.shields.io/static/v1?label=STATUS&message=IN%20DEVELOPMENT&color=GREEN&style=for-the-badge)

