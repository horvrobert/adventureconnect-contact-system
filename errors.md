ID: E-001
Date: 2026-02-11
Phase: (S3 / API Gateway / Lambda / DynamoDB / SES / Terraform)
Symptom: what you saw (1 sentence)
Exact error message: (paste it)
Root cause: (why it happened)
Fix: (what you changed)
Prevention: (how to avoid it next time)
What I learned: (1 bullet)
Related links: (optional)



## Error E-002: API Gateway 500 - Lambda Permission Missing

**ID:** E-002  
**Date:** 2026-02-21  
**Phase:** API Gateway  

**Symptom:**
API returns HTTP 500 with message "Internal server error"

**Exact error response:**
```
< HTTP/2 500
< x-amzn-errortype: InternalServerErrorException
{"message": "Internal server error"}
```

**What I observed:**
- curl command succeeded in reaching API Gateway
- API Gateway returned 500 error
- CloudWatch Logs showed NO new Lambda invocations
- Previous Lambda logs remained unchanged

**Root cause:**
Missing `aws_lambda_permission` resource - API Gateway had no permission to invoke Lambda function. Lambda's IAM role controls what Lambda can DO (outbound permissions). Lambda permission controls WHO can invoke Lambda (inbound permissions).

**Fix:**
Uncommented `aws_lambda_permission` resource in `api_gateway.tf`:
```hcl
resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.contact_form_api.execution_arn}/*/*"
}
```

Ran `terraform apply` to recreate the permission.

**Prevention:**
Always create `aws_lambda_permission` when integrating API Gateway with Lambda. The two permission systems are:
- IAM Role (what Lambda can access - DynamoDB, CloudWatch, etc.)
- Lambda Permission (who can invoke Lambda - API Gateway, S3, EventBridge, etc.)

**What I learned:**
- Lambda's IAM role alone is not enough for API Gateway integration
- 500 error + no CloudWatch logs = Lambda was never invoked
- API Gateway needs explicit permission via resource-based policy
- CloudWatch Logs absence is a key debugging signal (Lambda didn't run at all)

**Related links:**
- https://docs.aws.amazon.com/lambda/latest/dg/lambda-permissions.html


## E-003: Lambda environment variables set to placeholder values

Sprint: 3
Date: 2026-02-24

Symptom:
- Notification Lambda was being triggered by DynamoDB Stream (visible in CloudWatch)
- Lambda executed but SES returned: InvalidParameterValue - Illegal address
- No email delivered despite successful form submission

Root cause:
- notification_lambda.tf had placeholder text [EMAIL_ADDRESS] as environment variable values
- Terraform deployed the literal string "[EMAIL_ADDRESS]" to Lambda configuration
- SES rejected it as an invalid email address

How it was found:
- CloudWatch logs showed SES error with "Illegal address" message
- AWS Console → Lambda → Configuration → Environment variables confirmed
  SENDER_EMAIL and RECIPIENT_EMAIL contained "[EMAIL_ADDRESS]" not real addresses

Fix:
- Moved email addresses from hardcoded values to Terraform variables
- Created variables.tf with variable definitions
- Created terraform.tfvars with actual email values
- Added terraform.tfvars to .gitignore to keep values out of GitHub
- Ran terraform apply — 1 resource changed (Lambda environment variables updated)

Lesson learned:
- Always verify environment variable values in Lambda console after deployment
- Never leave placeholder text in Terraform files before applying
- terraform.tfvars must be in .gitignore before first commit — not after