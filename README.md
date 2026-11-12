<<<<<<< HEAD
# Terraform-dew
Infrastructure as Code (IaC) repository for automated provisioning and deployment of React and FastAPI applications to client Azure subscriptions using Terraform, GitHub Actions, Azure App Service, and secure CI/CD workflows.
=======
# Team-operated Azure client deployment (React + FastAPI)

**Scope:** This package is for your team to provision and maintain two Azure Linux Web Apps in an authorized customer's Azure subscription. It is **not** an Azure Marketplace self-service listing or Managed Application package.

**Generated against current published Microsoft, GitHub, and HashiCorp guidance (12 November 2026).** It has not been run against a customer subscription. Validate in a non-production subscription before using it for client onboarding.

## Included files

```text
main.tf
provider.tf
variables.tf
outputs.tf
terraform.tfvars.example
.gitignore
.github/workflows/terraform.yml
.github/workflows/provision-client.yml
README.md
```

Merge these files into the root of your application repository. Your application source code must also be present; it is **not** included in this package.

Expected default structure:

```text
repo/
  main.tf
  provider.tf
  variables.tf
  outputs.tf
  frontend/
    package.json
    package-lock.json
    src/...
  backend/
    main.py          # defines app = FastAPI()
    requirements.txt  # includes fastapi and uvicorn
  .github/workflows/terraform.yml
  .github/workflows/provision-client.yml
```

Defaults assume a **Vite React** application with `npm run build` -> `frontend/dist/` and FastAPI with `main:app`. For Create React App or different folders, override `FRONTEND_DIR`, `BACKEND_DIR`, `FRONTEND_BUILD_DIR` via GitHub Environment variables and update the frontend API environment variable name (currently `VITE_API_URL`).

## 1. Configure HCP Terraform

- Create an organization (for example `example-infra`) in HCP Terraform.
- Create **one workspace per customer/environment**, using the full name `client-<short-workspace>` (for example `client-acme-prod`). Set its **Execution Mode to Local**. This workflow runs the Terraform commands on GitHub runners and stores only state in HCP Terraform.
- Give the client's `TF_API_TOKEN` access only to the intended Terraform workspaces if possible. For HCP remote-backend workspace-prefix integration, the GitHub variable `TF_WORKSPACE` is the **short** name `acme-prod`, *not* `client-acme-prod`.
- The backend organization is deliberately supplied at runtime with `terraform init -backend-config="organization=$TFC_ORGANIZATION"`; it is not read from Terraform input variables. The backend uses the older supported `remote` style to support client-prefixed CLI workspaces and local execution. HashiCorp recommends the newer `cloud` block for new HCP Terraform integrations, but migrating requires redesigning workspace selection and execution semantics.
- If this Terraform configuration or subscription already has managed infrastructure, **do not just replace state or rename resources**. Review `terraform state mv`, `moved` blocks, imports, and backend migration first, or your plan may propose destructive replacements.

## 2. Prepare authorized Azure access

- Ask the customer to authorize a dedicated Microsoft Entra service principal to deploy to *their* subscription. It must have rights to create resource groups for initial provisioning; subscription-scope Contributor is one option for onboarding, but scope permissions down after resource creation wherever feasible.
- Store its credential JSON as the **GitHub Environment secret** `AZURE_CREDENTIALS`, formatted exactly as:

  ```json
  {"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}
  ```

- This matches the requested `Azure/login@v3.0.2` secret-based login method. Longer term, migrate to OIDC/federated credentials to avoid a long-lived client secret.
- The workflow compares the credential subscription and the logged-in Azure subscription against an **independently configured** GitHub Environment variable `AZURE_SUBSCRIPTION_ID` before provisioning.
- **Do not** commit the JSON or paste it into PRs, logs, workflow inputs or the repository.

## 3. Configure a GitHub Environment for each customer

Create an environment, for example **`acme-production`**, under your GitHub repository Settings. Configure required reviewers, prevent self-approval where supported, and restrict deployment to the trusted `main` branch. Availability of protection rules depends on your GitHub plan/repository visibility; check GitHub's environment documentation.

| Type | GitHub name | Example | Required? |
|---|---|---|---|
| Secret | `AZURE_CREDENTIALS` | Service principal JSON | Yes |
| Secret | `TF_API_TOKEN` | HCP Terraform token | Yes |
| Variable | `TFC_ORGANIZATION` | `example-infra` | Yes |
| Variable | `TF_WORKSPACE` | `acme-prod` | Yes |
| Variable | `CLIENT_CODE` | `acme` | Yes |
| Variable | `AZURE_LOCATION` | `eastus` | Yes |
| Variable | `AZURE_SUBSCRIPTION_ID` | `00000000-0000-0000-0000-000000000000` | Yes (must match client) |
| Variable | `REACT_WEBAPP_NAME` | `acme-react-prod-001` | Yes |
| Variable | `FASTAPI_WEBAPP_NAME` | `acme-api-prod-001` | Yes |
| Variable | `FRONTEND_DIR` | `frontend` | Optional |
| Variable | `BACKEND_DIR` | `backend` | Optional |
| Variable | `FRONTEND_BUILD_DIR` | `dist` | Optional |

If the same customer has multiple environments in the same subscription, assign a different `CLIENT_CODE` to each (for example, `acmeprod` and `acmedev`) so Azure resource group names do not collide. `CLIENT_CODE` must be 3–20 lowercase alphanumerics/hyphens. The workflow requires `TF_WORKSPACE` to begin with `${CLIENT_CODE}-` so the client/workspace pairing is harder to mix up. Azure Web App names must be globally unique. The App Service plan defaults to **B1**, which costs money and hosts both applications.

## 4. Choose the operation in GitHub Actions

Open **Actions → Client Azure Provisioning and Deployment → Run workflow** (on the `main` branch), select the client's existing environment, then choose an operation:

1. **`plan-only`** — checks the configuration and prints the Terraform plan; **no changes or application deployment**. This is the default. Review its output with your customer/reviewer.
2. **`provision-and-deploy`** — makes a fresh plan and applies that plan, builds Vite React, deploys FastAPI and deploys React. Use for first client onboarding or an intentional infrastructure update. Required Environment approval occurs **before** the job starts, not automatically between Plan and Apply. The plan is not uploaded as an artifact because saved plans may contain sensitive information.
3. **`deploy-only`** — builds and deploys both applications to an **already-provisioned** client. It reads the correct targets from that client's Terraform outputs but does not run `terraform plan/apply`.

`terraform.yml` runs only **static Terraform format and validate checks** on PRs and pushes to `main`; it does not use client credentials or apply any infrastructure. Avoid exposing `AZURE_CREDENTIALS` to pull-request jobs or untrusted code.

## 5. Important application assumptions and integration tasks

- **React**: Node.js 22 Linux app, compiled `dist/` contents are ZIP-deployed. Azure runs `pm2 serve /home/site/wwwroot --no-daemon --spa`. The app must actually read `import.meta.env.VITE_API_URL` for the build-time FastAPI base URL; change this if your app has a different configuration system. A Vite build embeds the API URL in generated browser assets; it is **not a secret**.
- **FastAPI**: Python 3.12 App Service uses the custom startup command `python -m uvicorn main:app --host 0.0.0.0 --port 8000`. Include `fastapi`, `uvicorn`, and any other runtime dependencies in `backend/requirements.txt`. App Service remote build (`SCM_DO_BUILD_DURING_DEPLOYMENT=true`) installs dependencies for ZIP deployment. If `main:app` is not your entrypoint, change `app_command_line`.
- **CORS**: Terraform sets a `FRONTEND_ORIGIN` app setting on FastAPI, but your application must **explicitly read it** and configure CORSMiddleware to permit the frontend origin. No CORS policy is magically created by the Terraform setting. Do not permit every origin in production unless required and justified.
- **Public networking**: The VNet/subnets/NSG are preserved from your original design but are not connected to either Web App. The names `public-subnet` and `private-subnet` do not guarantee isolation. To make the backend private, design an App Service networking solution including supported VNet integration/private endpoints, DNS and frontend access architecture. Do not assume browser-based React can call a private-only API.
- **Other app dependencies**: Database, identity provider, storage, Key Vault, domain names, monitoring, backups, production health checks, and any application-specific secrets must be configured separately if required by your project.
- **Plan capacity**: Both apps share a billable B1 App Service plan. Review quotas, CPU/memory and service sizing for production.
- **Secure packaging**: The backend packaging step excludes common local secrets (`.env`, keys, venv), but review your repo and exclude any additional sensitive/customer files before deployment. GitHub's `npm ci` needs a committed `package-lock.json`.
- **Deployment verification**: After deployment, inspect App Service logs and test the React route, FastAPI startup, correct API origin and CORS. The successful deploy step doesn't guarantee the whole application is healthy.
- **Client-owned Azure**: Confirm subscription ownership, authorized access, change windows, cost responsibility and teardown/data-retention policy with the customer before provisioning.

## 6. Documentation

- Microsoft: https://learn.microsoft.com/en-us/azure/app-service/deploy-github-actions
- Microsoft: https://learn.microsoft.com/en-us/azure/app-service/quickstart-python
- Microsoft: https://learn.microsoft.com/en-us/azure/app-service/configure-language-python
- Microsoft: https://learn.microsoft.com/en-us/azure/app-service/configure-language-nodejs
- Azure Login: https://github.com/Azure/login
- HCP Terraform remote backend: https://developer.hashicorp.com/terraform/language/backend/remote
- Terraform CLI `TF_WORKSPACE`: https://developer.hashicorp.com/terraform/cli/config/environment-variables
- GitHub deployment environments: https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments

## 7. What is NOT included

- Application source code (copy your existing `frontend/` and `backend/` projects).
- Azure Marketplace publishing artifacts (`mainTemplate.json`, `createUiDefinition.json`, Partner Center offer metadata). This is **team-operated deployment** as requested, not Marketplace self-service installation.
- A Terraform state migration for any preexisting deployment.

## Testing statement

The YAML files and embedded Bash snippets can be statically checked locally. This package has **not** been authenticated to Azure or HCP Terraform, has not run `terraform plan/apply` in a customer subscription, and has not installed the Azure provider in this preparation environment. Validate the resulting changes in a sandbox subscription with a real application before production onboarding.
>>>>>>> master
