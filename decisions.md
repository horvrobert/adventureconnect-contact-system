
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
