# AdventureConnect Contact System

A serverless contact form system built on AWS using Infrastructure as Code (Terraform). This project demonstrates cloud architecture fundamentals including serverless computing, NoSQL databases, event-driven architecture, and IAM security best practices.

## Project Status

**Current Phase:** SES Email Notifications (Sprint 3 Complete ✅)

**Completed:**
- ✅ Sprint 1: Lambda + DynamoDB backend
- ✅ Sprint 2: API Gateway + CORS + Rate Limiting
- ✅ Sprint 3: SES email notifications via event-driven architecture

**Next:**
- S3 static website hosting
- CloudWatch monitoring and alerting

**Note:** Infrastructure is deployed during active development sprints, then destroyed to minimize costs. All code is version-controlled and can be redeployed via Terraform in ~2 minutes.

## Architecture

### Sprint 1: Serverless Backend

![Sprint 1 Architecture](diagrams/architecture-sprint1.png)

**Components:**
- Lambda function (Python 3.11) processes submissions
- DynamoDB stores data with PAY_PER_REQUEST billing
- IAM roles with scoped permissions (table ARN, not wildcard)
- CloudWatch logs for monitoring

**Key Learning:** Lambda cold starts (~860ms) vs warm starts (~260ms)

### Sprint 2: API Gateway Integration

![Sprint 2 Architecture](diagrams/architecture-sprint2.png)

**Components:**
- API Gateway REST API provides public HTTPS endpoint
- CORS enabled for browser cross-origin requests
- Rate limiting: 1000 requests/day, 5 req/sec, burst 10
- Lambda permission grants API Gateway invocation access

**Key Learning:** Two permission systems — IAM Role (what Lambda can access) vs Lambda Permission (who can invoke Lambda)

### Sprint 3: SES Email Notifications

![Sprint 3 Architecture](diagrams/architecture-sprint3.png)

**Components:**
- DynamoDB Streams (NEW_IMAGE) triggers notification Lambda on every INSERT
- Dedicated notification Lambda reads stream record and sends email via SES
- SES delivers email to verified recipient address
- Separate IAM role for notification Lambda — SES permissions isolated from contact handler

**Key Learning:** Event-driven decoupling — form submission succeeds independently of email delivery. SES failures cannot affect the user-facing API response.

**Sandbox limitation:** SES account is in sandbox mode. In production, AWS support request required to send to unverified addresses.

## API Endpoint

After deployment via Terraform, the API endpoint follows this format:

```
https://{api-id}.execute-api.eu-central-1.amazonaws.com/prod/submit
```

**Example request:**
```bash
curl -X POST https://abc123xyz.execute-api.eu-central-1.amazonaws.com/prod/submit \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"Hello"}'
```

**Example response:**
```json
{
  "message": "Submission received",
  "submissionId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Security:** Rate limiting configured (1000 req/day max) to prevent abuse and cap costs at 0.12€ per month worst case.

## Project Structure

```
.
├── terraform/
│   ├── provider.tf                  # AWS provider configuration
│   ├── dynamodb.tf                  # DynamoDB table + Streams configuration
│   ├── iam.tf                       # IAM roles and policies (contact handler)
│   ├── lambda.tf                    # Contact form Lambda function
│   ├── api_gateway.tf               # API Gateway REST API + CORS + rate limiting
│   ├── notification_lambda.tf       # Notification Lambda + event source mapping
│   ├── notification_iam.tf          # IAM role, SES policy, Stream policy
│   └── variables.tf                 # Input variable definitions
├── lambda/
│   ├── lambda_function.py           # Contact form handler
│   └── notification_handler.py      # SES notification handler
├── diagrams/
│   ├── architecture-sprint1.png
│   ├── architecture-sprint2.png
│   └── architecture-sprint3.png
├── decisions.md                     # Architectural decisions and trade-offs
├── errors.md                        # Issues encountered and fixes
├── testing-log.md                   # Test results and verification
├── tshoot.md                        # Troubleshooting guides
└── README.md
```

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS account with appropriate permissions
- Verified SES email identities in eu-central-1

## Deployment

### 1. Clone Repository

```bash
git clone https://github.com/horvrobert/adventureconnect-contact-system.git
cd adventureconnect-contact-system
```

### 2. Package Lambda Functions

```bash
cd lambda
zip lambda_function.zip lambda_function.py
zip notification_handler.zip notification_handler.py
cd ..
```

### 3. Configure Variables

Create `terraform/terraform.tfvars` (not committed to Git):

```hcl
sender_email    = "your-verified-sender@example.com"
recipient_email = "your-verified-recipient@example.com"
```

### 4. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 5. Verify Deployment

```bash
# Check DynamoDB table and stream
aws dynamodb describe-table --table-name adventureconnect-submissions --region eu-central-1

# Check contact handler Lambda
aws lambda get-function --function-name adventureconnect-contact-handler --region eu-central-1

# Check notification Lambda
aws lambda get-function --function-name adventureconnect-notification-handler --region eu-central-1

# Check event source mapping (Stream → notification Lambda)
aws lambda list-event-source-mappings --function-name adventureconnect-notification-handler --region eu-central-1
```

## Testing

### Full End-to-End Test

```bash
curl -X POST https://YOUR-API-ID.execute-api.eu-central-1.amazonaws.com/prod/submit \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"Test submission"}'
```

Expected: `{"message":"Submission received","submissionId":"uuid-here"}`

Then check:
1. DynamoDB — record written with all fields
2. CloudWatch `/aws/lambda/adventureconnect-notification-handler` — email sent log
3. Inbox — email received from sender address

### CORS Preflight Test

```bash
curl -X OPTIONS https://YOUR-API-ID.execute-api.eu-central-1.amazonaws.com/prod/submit -v
```

### Verify DynamoDB Entry

```bash
aws dynamodb scan --table-name adventureconnect-submissions --region eu-central-1
```

### Check CloudWatch Logs

```bash
# Contact handler logs
aws logs tail /aws/lambda/adventureconnect-contact-handler --follow --region eu-central-1

# Notification handler logs
aws logs tail /aws/lambda/adventureconnect-notification-handler --follow --region eu-central-1
```

## Key Learnings

### Sprint 1: Serverless Backend

**Infrastructure as Code:** Terraform manages all AWS resources declaratively. State tracking enables safe infrastructure changes. Resource dependencies handled automatically.

**IAM Security:** Principle of least privilege applied throughout. Resource-scoped permissions (table ARN, not wildcard). Trust policies control service-to-service access.

**DynamoDB Design:** Partition key selection (UUID ensures uniqueness). PAY_PER_REQUEST vs PROVISIONED capacity trade-offs. Auto-scaling without capacity planning.

### Sprint 2: API Gateway Integration

**Two Permission Systems:** IAM Role controls what Lambda can access (DynamoDB, CloudWatch). Lambda Permission controls who can invoke Lambda (API Gateway, EventBridge). Removing Lambda permission causes 500 error with no CloudWatch logs — Lambda is never invoked.

**CORS Configuration:** OPTIONS method with MOCK integration returns CORS headers without invoking Lambda (~10ms vs ~200ms). Browser preflight requests require proper headers. MOCK eliminates 50% of Lambda invocations on browser traffic.

**Rate Limiting:** Usage plans protect against abuse and runaway costs. 1000 req/day limit caps worst-case monthly cost at 0.12€. Requests exceeding limit receive HTTP 429.

### Sprint 3: Event-Driven Architecture

**Decoupling via DynamoDB Streams:** Form submission and email delivery are independent operations. SES failure cannot cause form submission to fail. Stream retries automatically on notification Lambda failure.

**DynamoDB Typed Attribute Format:** Stream records deliver values as `{"S": "value"}` not `"value"`. Every attribute must be unwrapped with the type key (`["S"]`, `["N"]`, etc.). Missing this produces malformed output with no obvious error.

**IAM Blast Radius:** Notification Lambda has its own IAM role with only SES and Stream permissions. Contact handler role has no SES access. Compromise of one Lambda cannot be used to exploit the other.

**SES Resource `"*"` in IAM:** AWS does not support resource-level restrictions for `ses:SendEmail`. No ARN format exists for individual send operations. Compensate with verified identities, sending limits, and CloudWatch alerts.

## Cost Estimation

**Sprint 1 + 2 + 3 Combined (100 submissions/day):**

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| API Gateway | 3,000 requests | 0.009€ |
| Lambda (contact handler) | 3,000 invocations | 0€ (free tier) |
| Lambda (notification) | 3,000 invocations | 0€ (free tier) |
| DynamoDB | 3,000 writes | 0.003€ |
| DynamoDB Streams | 3,000 reads | 0€ (free tier) |
| SES | 3,000 emails | 0€ (first 62,000/month free) |
| **Total** | | **~0.012€** |

**All costs calculated in Euro (€) using 1 USD = 0.86 EUR**

## Roadmap

- [x] Sprint 1: Lambda + DynamoDB backend
- [x] Sprint 2: API Gateway + CORS + Rate Limiting
- [x] Sprint 3: SES email notifications
- [ ] Sprint 4: S3 static website frontend
- [ ] Sprint 5: CloudWatch monitoring and alerts

## Documentation

- **decisions.md** — Architectural decisions, alternatives considered, trade-offs
- **errors.md** — Issues encountered, root causes, fixes applied
- **testing-log.md** — Test results, inputs, outputs, execution metrics
- **tshoot.md** — Troubleshooting guides for common failure scenarios