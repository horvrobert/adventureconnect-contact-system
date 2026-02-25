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

---

## Troubleshooting Guide: SES Email Notifications Not Delivered

**Symptom:** Form submission succeeds (200 response) but no email arrives

**Step 1 — Check if notification Lambda was invoked at all:**
```bash
aws logs tail /aws/lambda/adventureconnect-notification-handler --follow --region eu-central-1
```

**No log group exists:**
- Lambda was never triggered
- Check event source mapping: `aws lambda list-event-source-mappings --function-name adventureconnect-notification-handler --region eu-central-1`
- Verify DynamoDB Stream is enabled: `aws dynamodb describe-table --table-name adventureconnect-submissions --region eu-central-1 | grep StreamSpecification`
- Check event source mapping state — should be `Enabled`

**Log group exists, shows `Skipping event: MODIFY`:**
- Stream is working but record came through as MODIFY not INSERT
- This can happen if the item already existed and was updated
- Submit a completely new form submission

**Log group exists, shows `Illegal address` or SES error:**
- Check environment variables in Lambda console
- AWS Console → Lambda → adventureconnect-notification-handler → Configuration → Environment variables
- Verify SENDER_EMAIL and RECIPIENT_EMAIL contain real addresses, not placeholders
- Verify both addresses are verified in SES: AWS Console → SES → Verified Identities

**Log group exists, shows `AccessDenied` for SES:**
- Notification Lambda IAM role missing SES policy
- Check: `aws iam list-attached-role-policies --role-name adventureconnect-notification-lambda-role`
- Should show `adventureconnect-notification-ses-policy` attached
- If missing, verify `notification_iam.tf` has the policy attachment resource and run `terraform apply`

**Log group shows success but email not in inbox:**
- Check spam/junk folder
- Verify recipient address is verified in SES sandbox
- SES sandbox only delivers to verified addresses — unverified recipients are silently rejected

**Step 2 — Verify Stream configuration:**
```bash
aws dynamodb describe-table \
  --table-name adventureconnect-submissions \
  --region eu-central-1 \
  --query 'Table.StreamSpecification'
```
Expected: `{"StreamEnabled": true, "StreamViewType": "NEW_IMAGE"}`

**Step 3 — Verify event source mapping:**
```bash
aws lambda list-event-source-mappings \
  --function-name adventureconnect-notification-handler \
  --region eu-central-1
```
Check `State` field — must be `Enabled`, not `Disabled` or `Creating`

---

## Troubleshooting Guide: CloudFront + S3 Frontend Issues

### Symptom 1: CloudFront returns 403 Forbidden

**Possible causes and fixes:**

**Bucket policy missing or misconfigured:**
```bash
aws s3api get-bucket-policy --bucket YOUR-BUCKET-NAME --region eu-central-1
```
- Principal must be `cloudfront.amazonaws.com` (Service, not AWS)
- Condition must include `AWS:SourceArn` matching your specific distribution ARN
- Resource must be `arn:aws:s3:::YOUR-BUCKET/*` (objects, not bucket itself)

**OAC not attached to distribution origin:**
- AWS Console → CloudFront → distribution → Origins tab
- Verify origin access control is set to your OAC, not "None"

**index.html not uploaded to S3:**
```bash
aws s3 ls s3://YOUR-BUCKET-NAME --region eu-central-1
```
If empty, upload: `aws s3 cp frontend/index.html s3://YOUR-BUCKET-NAME/index.html --region eu-central-1`

---

### Symptom 2: Form submission fails with CORS error in browser

**Browser console shows:** "Access to fetch blocked by CORS policy"

**Cause:** API Gateway URL in index.html is wrong or still set to placeholder

**Fix:**
1. Run `terraform output api_endpoint` to get current URL
2. Update line 619 in `frontend/index.html`:
   ```javascript
   const API_GATEWAY_URL = 'https://YOUR-ACTUAL-API-ID.execute-api.eu-central-1.amazonaws.com/prod/submit';
   ```
3. Re-upload: `aws s3 cp frontend/index.html s3://YOUR-BUCKET-NAME/index.html --region eu-central-1`
4. Invalidate CloudFront cache if needed:
   ```bash
   aws cloudfront create-invalidation --distribution-id YOUR-DIST-ID --paths "/*" --region eu-central-1
   ```

---

### Symptom 3: CloudFront serving stale content after index.html update

**Symptom:** Updated index.html uploaded to S3 but browser still shows old version

**Fix — Invalidate CloudFront cache:**
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR-DISTRIBUTION-ID \
  --paths "/*" \
  --region eu-central-1
```

Wait 1-2 minutes, then hard refresh browser (Ctrl+Shift+R).

**Get distribution ID:**
```bash
aws cloudfront list-distributions --query 'DistributionList.Items[].{Id:Id,Domain:DomainName}' --output table
```

---

### Symptom 4: CloudFront distribution takes too long to deploy

**Expected:** CloudFront distributions take 5-15 minutes to deploy globally after `terraform apply`

**Check status:**
```bash
aws cloudfront get-distribution --id YOUR-DIST-ID --query 'Distribution.Status'
```
- `InProgress` — still deploying, wait
- `Deployed` — ready to use