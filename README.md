# AdventureConnect Contact System

A serverless contact form system built on AWS using Infrastructure as Code (Terraform). This project demonstrates cloud architecture fundamentals including serverless computing, NoSQL databases, and IAM security best practices.

## Project Status

**Current Phase:** API Integration (Sprint 2 Complete ✅)

**Completed:**
- ✅ Sprint 1: Lambda + DynamoDB backend
- ✅ Sprint 2: API Gateway + CORS + Rate Limiting

**Next:**
- SES email notifications
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

**Key Learning:** Lambda cold starts (860ms) vs warm starts (260ms)

### Sprint 2: API Gateway Integration

![Sprint 2 Architecture](diagrams/architecture-sprint2.png)

**Components:**
- API Gateway REST API provides public HTTPS endpoint
- CORS enabled for browser cross-origin requests
- Rate limiting: 1000 requests/day, 5 req/sec, burst 10
- Lambda permission grants API Gateway invocation access

**Key Learning:** Two permission systems - IAM Role (what Lambda can access) vs Lambda Permission (who can invoke Lambda)

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
│   ├── provider.tf          # AWS provider configuration
│   ├── dynamodb.tf          # DynamoDB table definition
│   ├── iam.tf               # IAM roles and policies
│   ├── lambda.tf            # Lambda function configuration
│   └── api_gateway.tf       # API Gateway REST API + CORS + rate limiting
├── lambda/
│   └── lambda_function.py   # Python handler for form processing
├── diagrams/
│   ├── architecture-sprint1.png  # Sprint 1 architecture
│   └── architecture-sprint2.png  # Sprint 2 architecture
├── decisions.md             # Architectural decisions and trade-offs
├── errors.md                # Issues encountered and fixes
├── testing-log.md           # Test results and verification
├── tshoot.md                # Troubleshooting guides
└── README.md
```

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS account with appropriate permissions

## Deployment

### 1. Clone Repository

```bash
git clone https://github.com/horvrobert/adventureconnect-contact-system.git
cd adventureconnect-contact-system
```

### 2. Package Lambda Function

```bash
cd lambda
zip -r lambda_function.zip lambda_function.py
cd ..
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted to confirm deployment.

### 4. Verify Deployment

```bash
# Check DynamoDB table
aws dynamodb describe-table --table-name adventureconnect-submissions --region eu-central-1

# Check Lambda function
aws lambda get-function --function-name adventureconnect-contact-handler --region eu-central-1

# Check IAM role policies
aws iam list-attached-role-policies --role-name adventureconnect-lambda-role
```

## Testing

### API Gateway Endpoint Test

```bash
# Test POST request
curl -X POST https://YOUR-API-ID.execute-api.eu-central-1.amazonaws.com/prod/submit \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"Test submission"}'

# Expected response
{"message":"Submission received","submissionId":"uuid-here"}
```

### CORS Preflight Test

```bash
# Test OPTIONS request
curl -X OPTIONS https://YOUR-API-ID.execute-api.eu-central-1.amazonaws.com/prod/submit -v

# Should see headers:
# access-control-allow-origin: *
# access-control-allow-methods: POST,OPTIONS
# access-control-allow-headers: Content-Type,...
```

### Verify DynamoDB Entry

```bash
aws dynamodb scan --table-name adventureconnect-submissions --region eu-central-1
```

### Check CloudWatch Logs

```bash
aws logs tail /aws/lambda/adventureconnect-contact-handler --follow --region eu-central-1
```

## Key Learnings

### Sprint 1: Serverless Backend

**Infrastructure as Code:**
- Terraform manages all AWS resources declaratively
- State tracking enables safe infrastructure changes
- Resource dependencies handled automatically

**IAM Security:**
- Principle of least privilege applied throughout
- Resource-scoped permissions (table ARN, not wildcard `"*"`)
- Trust policies control service-to-service access

**DynamoDB Design:**
- Partition key selection (UUID ensures uniqueness)
- PAY_PER_REQUEST vs PROVISIONED capacity trade-offs
- Auto-scaling without capacity planning

### Sprint 2: API Gateway Integration

**Two Permission Systems:**
- IAM Role: What Lambda can ACCESS (DynamoDB, CloudWatch)
- Lambda Permission: WHO can INVOKE Lambda (API Gateway, EventBridge, S3)
- Removing Lambda permission → 500 error, no CloudWatch logs (Lambda never invoked)

**CORS Configuration:**
- OPTIONS method with MOCK integration (no Lambda call, ~10ms response)
- Browser preflight requests require proper headers
- `Access-Control-Allow-Origin: *` enables cross-origin requests

**Rate Limiting:**
- Usage plans protect against abuse and runaway costs
- 1000 req/day limit caps worst-case monthly cost at 0.12€
- Requests exceeding limit get HTTP 429 (Too Many Requests)

## Cost Estimation

**Sprint 1 + 2 Combined (100 submissions/day):**

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| API Gateway | 3,000 requests | 0.009€ |
| Lambda | 3,000 invocations | 0€ (free tier) |
| DynamoDB | 3,000 writes | 0.003€ |
| **Total** | | **~0.012€** |

**With rate limiting at max (1000 req/day):**
- API Gateway: 0.09€
- Lambda: 0€ (free tier)
- DynamoDB: 0.03€
- **Total: ~0.12€ per month**

**All costs calculated in Euro (€) using 1 USD = 0.86 EUR**

## Roadmap

- [x] Sprint 1: Lambda + DynamoDB backend
- [x] Sprint 2: API Gateway + CORS + Rate Limiting
- [ ] Sprint 3: SES email notifications
- [ ] Sprint 4: S3 static website frontend
- [ ] Sprint 5: CloudWatch monitoring and alerts

## Documentation

- **decisions.md**: Architectural decisions, alternatives considered, trade-offs
- **testing-log.md**: Test results, inputs, outputs, execution metrics
