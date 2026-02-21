## Troubleshooting Guide: Lambda Access Denied to DynamoDB

**Symptom:** Lambda returns 500 error, CloudWatch shows "User: arn:aws:sts::123:assumed-role/lambda-role is not authorized to perform: dynamodb:PutItem"

**Troubleshooting Steps:**

1. Verify Lambda role: `aws lambda get-function --function-name X`
   - Check `Role` field matches expected IAM role ARN

2. List attached policies: `aws iam list-attached-role-policies --role-name X`
   - Confirm DynamoDB policy is attached

3. Inspect policy document: `aws iam get-policy-version --policy-arn X --version-id v1`
   - Action must include `dynamodb:PutItem`
   - Resource must match exact table ARN (not "*")

4. Check CloudWatch Logs: `aws logs tail /aws/lambda/function-name --follow`
   - Reveals which action/resource was denied

5. Verify trust policy: `aws iam get-role --role-name X`
   - Principal must be `lambda.amazonaws.com`

**Common causes:**
- Policy attached to wrong role
- Resource ARN typo in policy
- Missing PutItem action
- Lambda not using intended role


---

## Troubleshooting Guide: API Gateway Returns 403/500

### Symptom 1: API Gateway Returns 500 "Internal Server Error"

**CloudWatch shows:** No Lambda logs (Lambda was never invoked)

**Troubleshooting Steps:**

1. Check if Lambda permission exists:
```bash
   aws lambda get-policy --function-name adventureconnect-contact-handler
```
   Look for statement allowing `apigateway.amazonaws.com`

2. Verify in Terraform:
```bash
   grep -r "aws_lambda_permission" terraform/
```
   Should see `api_gateway_lambda_permission` resource

3. Check source ARN in permission matches your API:
```bash
   aws apigateway get-rest-apis --query 'items[?name==`adventureconnect-api`].id'
```
   Permission source ARN should reference this API ID

4. If missing, add `aws_lambda_permission` and apply:
```hcl
   resource "aws_lambda_permission" "api_gateway_lambda_permission" {
     statement_id  = "AllowAPIGatewayInvoke"
     action        = "lambda:InvokeFunction"
     function_name = aws_lambda_function.lambda_function.function_name
     principal     = "apigateway.amazonaws.com"
     source_arn    = "${aws_api_gateway_rest_api.contact_form_api.execution_arn}/*/*"
   }
```

**Common causes:**
- `aws_lambda_permission` resource missing entirely
- Wrong principal (not `apigateway.amazonaws.com`)
- Source ARN pointing to wrong API ID
- Permission exists but for different Lambda function

---

### Symptom 2: CORS Error in Browser

**Browser console shows:** "No 'Access-Control-Allow-Origin' header is present"

**Troubleshooting Steps:**

1. Check if OPTIONS method exists:
```bash
   aws apigateway get-method \
     --rest-api-id YOUR_API_ID \
     --resource-id YOUR_RESOURCE_ID \
     --http-method OPTIONS \
     --region eu-central-1
```

2. Verify OPTIONS integration response has CORS headers:
```bash
   aws apigateway get-integration-response \
     --rest-api-id YOUR_API_ID \
     --resource-id YOUR_RESOURCE_ID \
     --http-method OPTIONS \
     --status-code 200 \
     --region eu-central-1
```
   Should show `Access-Control-Allow-Origin` in response parameters

3. Test OPTIONS manually:
```bash
   curl -X OPTIONS https://YOUR_API_URL/prod/submit -v
```
   Look for `access-control-allow-origin: *` in headers

4. Check API Gateway deployment includes CORS configuration:
```bash
   aws apigateway get-stage \
     --rest-api-id YOUR_API_ID \
     --stage-name prod \
     --region eu-central-1
```

**Common causes:**
- OPTIONS method not deployed (forgot `terraform apply`)
- Integration response missing CORS headers
- Method response doesn't declare headers as `true`
- Deployment created before OPTIONS method existed

---

### Symptom 3: Rate Limit Exceeded (429 Error)

**API returns:** `{"message":"Too Many Requests"}`

**Diagnosis:**

1. Check current usage plan limits:
```bash
   aws apigateway get-usage-plans --region eu-central-1
```

2. Check actual usage:
```bash
   aws apigateway get-usage \
     --usage-plan-id YOUR_PLAN_ID \
     --start-date 2026-02-21 \
     --end-date 2026-02-21 \
     --region eu-central-1
```

**Expected behavior:** This is working as designed (cost protection)

**To increase limits temporarily:**
- Update `quota_settings.limit` in `api_gateway.tf`
- Run `terraform apply`