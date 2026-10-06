Secure Azure Environment with Terraform
A hands-on project that provisions a small and security-focused Azure environment; focusing on cloud security practices, network segmentation, auto scaling, private data access. 
**Note:** A learning project. 
Architecture

<img width="2720" height="2576" alt="terrapractice_azure_environment_v5" src="https://github.com/user-attachments/assets/d1c53f76-b78a-48a0-b37c-8ea808a52ea9" />


 
Inbound: Internet, then the firewall’s public IP, then a DNAT rule that translates it to the load balancer’s private IP, then the VM scale set. Because the load balancer has no public IP, the firewall is the only way in.
Data: The scale set connects to SQL on port 1433 through a private endpoint in the backend subnet. A private DNS zone linked to the Vnet resolves the SQL hostname to the endpoint’s private IP. The backend NSG allows 1433 from the frontend subnet only.
Outbound: The frontend subnet’s route table sends outbound traffic to the firewall, which denies by default. 
What I learned
-	Network segmentation
-	Making a single public entry protected by a firewall
-	How NSG rules interact with Azure’s default rules
-	Using route tables to force outbound traffic through a firewall.
-	Linking a load balancer to a VM scale set with a backend pool, health probe and rule


<img width="1910" height="870" alt="Screenshot 2026-10-06 001709" src="https://github.com/user-attachments/assets/1ba1574e-c8e4-473f-a42f-18f9f46398f4" />

 
