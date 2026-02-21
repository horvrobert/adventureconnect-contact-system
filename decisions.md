
## Decision: Standalone IAM policy with attachments (not inline policy)

Why this exists:
- Lambda needs DynamoDB access (PutItem, GetItem) scoped to specific table only
- Using standalone policy (`aws_iam_policy`) instead of inline policy (`aws_iam_role_policy`)

Alternatives considered:
- Inline policy attached directly to the role

Why rejected:
- Wanted consistency with existing IAM structure in this project
- Standalone policies can be reused across multiple roles if needed later
- Clearer separation between policy definition and role definition

Trade-offs accepted:
- More resources to manage (policy + attachment vs just inline policy)
- Slightly more verbose Terraform code
- For single-use case like this, inline would have been simpler
- Would reconsider if this policy is never reused elsewhere

Related:
- Policy scoped to specific table ARN (not "*") following least privilege principle
- Uses Terraform references (aws_dynamodb_table.dynamodb.arn) not hardcoded ARNs


## Decision: DynamoDB PAY_PER_REQUEST billing mode

Why this exists:
- Contact form has unpredictable traffic (could be 10/day or 1000/day)
- PAY_PER_REQUEST auto-scales without capacity planning

Alternatives considered:
- PROVISIONED capacity mode

Why rejected:
- Would need to guess read/write capacity units upfront
- Risk of throttling during traffic spikes OR paying for unused capacity
- Early-stage project lacks traffic patterns to optimize provisioned capacity

Trade-offs accepted:
- Higher cost per request (~$1.25/million writes vs ~$0.50 provisioned)
- Acceptable for low-volume contact form
- Would reconsider at scale (>1M requests/month where provisioned becomes cheaper)


Interview question: "How do you verify your Terraform deployed correctly?"
Bad answer: "I check the AWS Console."
Good answer: "I verify infrastructure in three ways:

Terraform state shows successful apply
AWS CLI commands confirm resources match expected configuration
Actual integration tests (which we'll do when Lambda is deployed)"


## Decision: Lambda timeout set to 10 seconds

Why this exists:
- Contact form writes to DynamoDB (typically 50-200ms)
- Cold starts add 1-2 seconds on first invocation
- 10 seconds provides comfortable buffer for unpredictable network conditions

Alternatives considered:
- Default 3 seconds
- Maximum 15 minutes

Why rejected:
- 3 seconds: Could timeout during cold start + slow network
- 15 minutes: Unnecessary for simple DynamoDB write operation

Trade-offs accepted:
- Lambda can run up to 10 seconds before timing out (could waste compute time if something hangs)
- For contact form, acceptable trade-off for reliability



## Decision: API Gateway REST API (not HTTP API)

Why this exists:
- Need public HTTPS endpoint to expose Lambda function to frontend
- REST API provides production-grade features (request validation, usage plans, detailed metrics)
- Industry standard for enterprise serverless architectures

Alternatives considered:
- HTTP API (simpler, 70% cheaper)
- Lambda Function URLs (free, simplest)

Why rejected:
- HTTP API: Fewer features, less common in enterprise environments, limited request validation
- Function URLs: No request throttling, no usage plans, no API keys, harder to add authentication later

Trade-offs accepted:
- Higher cost ($3.50 vs $1.00 per million requests for HTTP API)
- More complex Terraform configuration
- Slightly higher latency (~10-20ms)
- For learning project targeting enterprise role: production patterns > cost optimization
- At contact form scale (100 requests/day): cost difference is ~0.008 € per month (negligible)

When to reconsider:
- If building high-volume public API where cost matters (>10M requests/month)
- If only need simple Lambda proxy with no advanced features
- If optimizing for lowest latency (HTTP API is ~10ms faster)


## Decision: Lambda Permission for API Gateway Invocation

Why this exists:
- API Gateway needs explicit permission to invoke Lambda function
- Lambda's IAM role controls what Lambda can do (outbound permissions)
- Lambda permissions control who can invoke Lambda (inbound permissions)

How it works:
- Resource-based policy attached to Lambda function itself
- Grants apigateway.amazonaws.com service permission to invoke
- Uses source_arn to restrict which API Gateway can invoke (not any random API)

Without this:
- API Gateway receives requests from users
- Attempts to invoke Lambda
- Gets Access Denied error (403)
- Users see "Internal Server Error"

Security consideration:
- source_arn restricts invocation to specific API Gateway (not all APIs in account)
- Format: arn:aws:execute-api:REGION:ACCOUNT:API_ID/*/* (any stage, any method)


## Decision: API Gateway REST API (not HTTP API)

**Why this exists:**
Need public HTTPS endpoint to expose Lambda function to frontend. REST API provides production-grade features over simpler HTTP API.

**Alternatives considered:**
- HTTP API (simpler, 70% cheaper: 0.86 € vs 3.01 € per million requests)
- Lambda Function URLs (free, direct invocation)

**Why rejected:**
- HTTP API: Fewer features (no request validation, no usage plans, limited monitoring)
- Function URLs: No throttling, no API keys, harder to add authentication later, no usage analytics

**Trade-offs accepted:**
- Higher cost: 3.01 € per million requests vs 0.86 € for HTTP API
- More complex Terraform configuration (9 resources vs 3 for HTTP API)
- Slightly higher latency (~10-20ms overhead from additional features)

**Why acceptable:**
- At contact form scale (100 requests/day), cost difference is ~0.008 € per month (negligible)
- Learning production patterns matters more than cost optimization for portfolio project
- Enterprise employers expect REST API experience
- Usage plans enable rate limiting for cost protection (1000 req/day max = 0.09 € monthly worst case)

**When to reconsider:**
- High-volume public API (>10M requests/month) where cost matters
- Simple Lambda proxy with no need for request validation or usage plans
- Optimizing for lowest possible latency (HTTP API is ~10ms faster)
```
