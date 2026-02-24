## Sprint 1, Day 2: Lambda Integration Test

**Date:** 2026-02-18
**Test:** Manual Lambda invocation via AWS Console

**Test Input:**
```json
{
  "body": "{\"name\":\"Test User\",\"email\":\"test@example.com\",\"message\":\"Test submission\"}"
}
```

**Expected Result:**
- Lambda returns 200 status
- Item written to DynamoDB with generated submissionId

**Actual Result:**
✅ Lambda executed successfully
✅ DynamoDB item created:
  - submissionId: 42abfad4-9f37-4894-9715-92f57d0a03e9
  - All fields present and correct
  - Timestamp: 2026-02-18T08:16:32.520276

**Execution time:** ~200ms (warm start)

**What I learned:**
- Lambda-DynamoDB integration works with proper IAM permissions
- Environment variables correctly passed to Lambda runtime
- UUID generation produces unique identifiers as expected

---

## Sprint 2: API Gateway Integration Testing

**Date:** 2026-02-21

### Test 1: Successful POST via API Gateway

**Command:**
```bash
curl -X POST https://xp02d6nywi.execute-api.eu-central-1.amazonaws.com/prod/submit \
  -H "Content-Type: application/json" \
  -d '{"name":"Robert Test","email":"robert@test.com","message":"Testing API Gateway integration"}'
```

**Expected:** 200 status, JSON with submissionId
**Actual:** `{"message":"Submission received","submissionId":"41db290a-b38a-413d-9488-971db22469a0"}`
**Result:** ✅ Pass

**CloudWatch Metrics:**
- Cold start: 714ms (488ms init + 225ms execution)
- Warm start: 70ms (0ms init + 69ms execution)
- Memory used: 86-87 MB out of 128 MB allocated

### Test 2: CORS Preflight (OPTIONS)

**Command:**
```bash
curl -X OPTIONS https://xp02d6nywi.execute-api.eu-central-1.amazonaws.com/prod/submit -v
```

**Expected:** Headers include Access-Control-Allow-Origin: *
**Actual:**
```
access-control-allow-origin: *
access-control-allow-methods: POST,OPTIONS
access-control-allow-headers: Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token
```
**Result:** ✅ Pass

### Test 3: DynamoDB Data Verification

**Command:**
```bash
aws dynamodb scan --table-name adventureconnect-submissions --region eu-central-1
```

**Expected:** Test submission present with all fields
**Actual:** 2 submissions found, all fields correct (submissionId, name, email, message, timestamp, status)
**Result:** ✅ Pass

### Test 4: Missing Lambda Permission (Breaking Test)

**Setup:** Removed `aws_lambda_permission` resource, ran `terraform apply`

**Command:**
```bash
curl -X POST https://xp02d6nywi.execute-api.eu-central-1.amazonaws.com/prod/submit \
  -H "Content-Type: application/json" \
  -d '{"name":"Break Test","email":"test@test.com","message":"Testing without permission"}'
```

**Expected:** 500 error, no Lambda invocation
**Actual:**
- HTTP 500: `{"message": "Internal server error"}`
- CloudWatch: No new log entries (Lambda never invoked)

**Result:** ✅ Expected behavior — documented in errors.md (E-002)

**Fix:** Restored `aws_lambda_permission`, verified API works again

---

## Sprint 3: SES Email Notification Testing

**Date:** 2026-02-24

### Test 1: Manual Lambda invocation with mock stream event

**Method:** AWS Console → Lambda → adventureconnect-notification-handler → Test tab

**Test Event:**
```json
{
  "Records": [
    {
      "eventName": "INSERT",
      "dynamodb": {
        "NewImage": {
          "submissionId": {"S": "test-123"},
          "name": {"S": "Robert Test"},
          "email": {"S": "robert@test.com"},
          "message": {"S": "Test message"},
          "timestamp": {"S": "2026-02-24T09:00:00"}
        }
      }
    }
  ]
}
```

**Expected:** Lambda executes, SES sends email, CloudWatch shows success log
**Actual:** SES error — `InvalidParameterValue: Illegal address`
**Result:** ❌ Fail — root cause: environment variables contained placeholder text `[EMAIL_ADDRESS]`
**Fix:** Documented in errors.md (E-003). Moved to Terraform variables + terraform.tfvars.

### Test 2: Manual Lambda invocation after environment variable fix

**Method:** AWS Console → Lambda → Test (same event as Test 1)
**Expected:** Email delivered to robik.horvath@gmail.com
**Actual:**
- CloudWatch: `Failed to send email for test-123` → `raise` triggered retry
**Result:** ❌ Fail — environment variables still showing `[EMAIL_ADDRESS]` in console

**Fix:** Ran `terraform apply` after updating `notification_lambda.tf` to use `var.sender_email` and `var.recipient_email`. 1 resource changed.

### Test 3: End-to-end form submission test

**Command:**
```bash
curl -X POST https://b8kceclkw4.execute-api.eu-central-1.amazonaws.com/prod/submit \
  -H "Content-Type: application/json" \
  -d '{"name":"Robert Test","email":"robert@test.com","message":"Testing API Gateway integration"}'
```

**Expected:**
- API returns 200 + submissionId
- DynamoDB record written
- Stream triggers notification Lambda
- Email arrives at robik.horvath@gmail.com

**Actual:**
- API: `{"message":"Submission received","submissionId":"ba9cd602-3066-4d8c-9802-faf9f5fef443"}` ✅
- DynamoDB: Record written with all fields ✅
- CloudWatch `/aws/lambda/adventureconnect-notification-handler`: `Email sent for submission ba9cd602...` ✅
- Email received at robik.horvath@gmail.com with correct name, email, message, timestamp ✅

**Result:** ✅ Pass

**CloudWatch Metrics (notification Lambda):**
- Duration: 361.59ms (includes SES API call)
- Billed duration: 362ms
- Memory used: 85 MB out of 128 MB allocated

**Notable:** Email delivered was from an earlier curl test (timestamp 2026-02-24T09:03:19) — the Stream retained the record and delivered it once the Lambda environment variables were corrected. Demonstrates automatic retry behaviour working as designed.

### Test 4: MODIFY event filtering verification

**Method:** Manually updated an existing DynamoDB item via AWS Console to trigger a MODIFY stream event

**Expected:** Notification Lambda invoked but skips record — logs show `Skipping event: MODIFY`
**Actual:** CloudWatch log shows `Skipping event: MODIFY` ✅
**Result:** ✅ Pass — INSERT filter working correctly, no duplicate emails on updates