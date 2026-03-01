# Architectural Decisions — adventureconnect-contact-system

---

## Decision: Standalone IAM policy with attachments (not inline policy)

Why this exists:
- Lambda needs DynamoDB access (PutItem, GetItem) scoped to specific table only
- Using standalone policy (`aws_iam_policy`) instead of inline policy (`aws_iam_role_policy`)

Alternatives considered:
- Inline policy attached directly to the role

Why rejected:
- Standalone policies can be reused across multiple roles if needed later
- Clearer separation between policy definition and role definition
- Consistency with IAM structure across the project

Trade-offs accepted:
- More resources to manage (policy + attachment vs just inline policy)
- Slightly more verbose Terraform code
- For single-use case like this, inline would have been simpler
- Would reconsider if this policy is never reused elsewhere

Related:
- Policy scoped to specific table ARN (not "*") following least privilege principle
- Uses Terraform references (aws_dynamodb_table.dynamodb.arn) not hardcoded ARNs

---

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
- Higher cost per request (~1.13 € per million writes vs ~0.45 € provisioned)
- Acceptable for low-volume contact form
- Would reconsider at scale (>1M requests/month where provisioned becomes cheaper)

---

## Decision: Lambda timeout set to 10 seconds

Why this exists:
- Contact form writes to DynamoDB (typically 50-200ms)
- Cold starts add 1-2 seconds on first invocation
- 10 seconds provides comfortable buffer for unpredictable network conditions

Alternatives considered:
- Default 3 seconds
- Maximum 15 minutes

Why rejected:
- 3 seconds: Could timeout during cold start + slow network conditions
- 15 minutes: Unnecessary for a simple DynamoDB write operation

Trade-offs accepted:
- Lambda can run up to 10 seconds before timing out (could waste compute time if something hangs)
- For contact form use case, acceptable trade-off for reliability

---

## Decision: API Gateway REST API (not HTTP API)

Why this exists:
- Need public HTTPS endpoint to expose Lambda function to frontend
- REST API provides production-grade features: request validation, usage plans, detailed metrics
- Industry standard for enterprise serverless architectures

Alternatives considered:
- HTTP API (simpler, ~70% cheaper: 0.86 € vs 3.01 € per million requests)
- Lambda Function URLs (free, direct invocation)

Why rejected:
- HTTP API: Fewer features, no request validation, no usage plans, limited monitoring
- Function URLs: No throttling, no API keys, harder to add authentication later, no usage analytics

Trade-offs accepted:
- Higher cost: 3.01 € per million requests vs 0.86 € for HTTP API
- More complex Terraform configuration (9 resources vs 3 for HTTP API)
- Slightly higher latency (~10-20ms overhead from additional features)
- At contact form scale (100 requests/day), cost difference is ~0.008 € per month (negligible)
- Learning production patterns matters more than cost optimization for portfolio project
- Usage plans enable rate limiting for cost protection (1000 req/day max = 0.09 € monthly worst case)

When to reconsider:
- High-volume public API (>10M requests/month) where cost matters
- Simple Lambda proxy with no need for request validation or usage plans
- Optimizing for lowest possible latency (HTTP API is ~10ms faster)

---

## Decision: Lambda Permission for API Gateway Invocation

Why this exists:
- API Gateway needs explicit permission to invoke Lambda function
- Lambda's IAM role controls what Lambda can do (outbound permissions)
- Lambda resource-based policy controls who can invoke Lambda (inbound permissions)

How it works:
- Resource-based policy attached to Lambda function itself
- Grants apigateway.amazonaws.com service permission to invoke
- Uses source_arn to restrict which specific API Gateway can invoke (not any API in the account)

Without this:
- API Gateway receives request from user
- Attempts to invoke Lambda
- Gets Access Denied (403)
- User sees Internal Server Error

Security consideration:
- source_arn restricts invocation to specific API Gateway, not all APIs in account
- Format: arn:aws:execute-api:REGION:ACCOUNT:API_ID/*/* (any stage, any method)

---

## Decision: SES integration architecture — asynchronous via DynamoDB Streams

Why this exists:
- Contact form submissions need to trigger email notifications via SES
- Two viable patterns: call SES directly inside existing Lambda, or trigger a separate Lambda via DynamoDB Streams

Alternatives considered:
- Synchronous: call ses.send_email() inside existing contact form Lambda after DynamoDB write

Why synchronous rejected:
- SES failure or timeout causes API to return 500 even if form data was saved successfully
- Increases API response latency by SES call duration (~200-500ms)
- Blast radius: SES outage breaks the entire form submission flow
- Violates single responsibility principle — one Lambda doing two unrelated jobs

Why asynchronous chosen:
- Form submission succeeds independently of email delivery
- SES failures do not affect user-facing API response or form data persistence
- DynamoDB Streams provide automatic retry on notification Lambda failure
- IAM blast radius contained: SES permissions isolated to notification Lambda only
- Decoupled components are easier to debug, test, and replace independently

Trade-offs accepted:
- Higher complexity: additional Lambda, IAM role, DynamoDB Stream, and event source mapping
- Email delivery is eventually consistent — arrives seconds after form submission, not instantly
- More Terraform resources to manage
- For contact form use case: acceptable, form data persistence matters more than immediate email delivery

When to reconsider:
- If email delivery must be confirmed synchronously before returning success to user
- If DynamoDB Streams cost becomes a concern at high volume

---

## Decision: SES sandbox mode — verified identities only

Why this exists:
- AWS SES accounts start in sandbox mode in all regions, including eu-central-1
- Sandbox restricts sending to verified email addresses only
- Cannot send to arbitrary user-submitted email addresses

Current configuration:
- Sender: [EMAIL_ADDRESS] (verified SES identity)
- Recipient: [EMAIL_ADDRESS] (verified SES identity)
- Notification emails hardcoded to go to verified recipient, not user-submitted address

Production path:
- Submit AWS SES production access request via support ticket
- Provide use case: transactional contact form notifications
- Once approved, send to unverified addresses (actual user emails)
- Update Lambda to send confirmation to user-submitted address

Why programmatic verification of arbitrary addresses is not possible:
- Verification requires recipient to click a confirmation link — human-in-the-loop by design
- Prevents SES from being used as open relay for spam
- AWS enforces this at service level, cannot be bypassed in code

Trade-offs accepted:
- In current state, users do not receive confirmation emails — only site owner is notified
- Acceptable for portfolio/learning project demonstrating the architecture
- Production readiness is one AWS support request away from full functionality

Why SES resource is set to * in IAM policy:
- AWS does not support resource-level restrictions for "ses:SendEmail"
- There is no ARN format for "ses:SendEmail"
- Trying to put an ARN there, the policy would either error or silently fail to grant access
- In practice compensate with other controls — verified identities, sending limits, and CloudWatch alerts on unexpected sending volume

---


## Decision: DynamoDB Streams view type — NEW_IMAGE only

Why this exists:
- Notification Lambda needs to read submitted form data to build email body
- DynamoDB Streams offers four view types: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES

Alternatives considered:
- KEYS_ONLY: records only the partition key of the changed item
- NEW_AND_OLD_IMAGES: records both the item before and after the change
- OLD_IMAGE: records only the item state before the change

Why rejected:
- KEYS_ONLY: would require a secondary GetItem call back to DynamoDB to fetch name, email, message — extra network call, extra IAM permission, extra latency, unnecessary complexity
- NEW_AND_OLD_IMAGES: doubles record size and cost, old state is irrelevant for sending a notification email
- OLD_IMAGE: useless for INSERT events, no previous state exists

Why NEW_IMAGE chosen:
- Contains the full item as it was written — name, email, message, timestamp all available immediately
- No secondary DynamoDB call needed, notification Lambda stays stateless and simple
- Minimal data, minimal cost

Trade-offs accepted:
- If notification logic ever needs to detect what changed between writes, NEW_IMAGE alone is insufficient
- Acceptable for contact form use case where only INSERTs are relevant

---

## Decision: DynamoDB typed attribute format — explicit type unwrapping in Lambda

Why this exists:
- DynamoDB Streams deliver item data in DynamoDB's native typed format, not plain JSON
- Every attribute value is wrapped: { "S": "Robert" } not "Robert"
- Type codes: S (String), N (Number), B (Binary), BOOL (Boolean), NULL (Null), M (Map), L (List), SS (String Set), NS (Number Set), BS (Binary Set)

Why it matters:
- Lambda code must unwrap explicitly: record["dynamodb"]["NewImage"]["email"]["S"]
- Accessing record["dynamodb"]["NewImage"]["email"] returns {"S": "robert@gmail.com"} — not the value
- Failure to unwrap produces malformed email bodies and subtle bugs

How we handle it:
- Notification Lambda accesses each field with explicit type key ["S"]
- Only String type needed for contact form fields: name, email, message, timestamp

Related:
- DynamoDB is schema-flexible — type wrappers allow mixed item types in one table without fixed schema
- This format appears in all Stream records regardless of view type chosen


## Decision: Use Origin Access Control (OAC) to restrict access to S3

Why this exists:
- S3 hosts contact form website and CloudFront needs access to it

Alternatives considered:
- Origin Access Identity (OAI)

Why rejected:
- OAI cannot be configured if S3 is set to host a website
- OAI is a legacy feature that AWS has deprecated in favor of OAC

Why OAC chosen:
- Enables CF customers to easily secure their S3 origins by permitting only designated CF distributions to access their S3 buckets
- Provides server-side encryption with KMS keys when performing uploads and downloads through CF distribution
- OAC supports more S3 authentication methods including SSE-KMS
- OAC is the current AWS-recommended approach

Trade-offs accepted:
- OAC is slightly more complex to configure than OAI
- Compared to making the bucket fully public, both OAC and OAI add complexity and a dependency on CloudFront — if CloudFront goes down, the site is inaccessible even though S3 is fine



## Decision: Use SNS topic as alarm action

Why this exists:
- CloudWatch alarms require an action target — they cannot notify anyone directly
- SNS acts as the notification middleman between CloudWatch and the recipient

Alternatives considered:
- SNS with email subscription (chosen)
- SNS with SMS subscription
- SNS with Lambda subscription forwarding to ChatOps (Slack, Teams)

Why rejected:
- SMS is expensive and not always delivered
- ChatOps requires additional Lambda and webhook integration — unnecessary complexity for a portfolio project

Why SNS with email subscription chosen:
- CloudWatch can only trigger actions via SNS topic ARN — email is the SNS delivery protocol, not a CloudWatch feature
- SNS can fan out to multiple subscribers simultaneously (email, SMS, Lambda) — one topic serves all notification channels
- SNS is highly available and durable
- Email subscription is free and sufficient for this use case

Trade-offs accepted:
- SNS adds a dependency — if SNS goes down, the alarm still triggers but the notification will not be sent
- After terraform apply, SNS subscription confirmation email must be clicked manually — until confirmed, alerts are silently dropped


