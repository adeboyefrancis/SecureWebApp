# Secure Web App Deployment

## Architecture
- **Azure App Service** with staging slots for blue/green deployment
- **Azure Key Vault** for secure secret management
- **Terraform** for Infrastructure as Code
- **GitHub Actions** for CI/CD pipeline

## Security Features
- SAST with CodeQL
- DAST with OWASP ZAP
- Dependency scanning
- Manual approval gates
- Managed identities for Key Vault access
- HTTPS enforcement

## Local Development
```bash
cd SecureWebApp
dotnet run

## Cross Platform Drift using Sed to replace tfvars placeholder with ENV variables
# Detect OS and set sed command accordingly

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/secureapp1234/${APP_NAME}/g" infra/terraform.tfvars
    sed -i '' "s/rg-secureapp1234/${RG_NAME}/g" infra/terraform.tfvars
    sed -i '' "s/kv-secureapp1234/${KV_NAME}/g" infra/terraform.tfvars
else
    # Linux
    sed -i "s/secureapp1234/${APP_NAME}/g" infra/terraform.tfvars
    sed -i "s/rg-secureapp1234/${RG_NAME}/g" infra/terraform.tfvars
    sed -i "s/kv-secureapp1234/${KV_NAME}/g" infra/terraform.tfvars
fi