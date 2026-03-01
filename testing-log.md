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
**Actual:** CloudWatch: `Failed to send email for test-123` → `raise` triggered retry
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

### Test 4: MODIFY event filtering verification

**Method:** Manually updated an existing DynamoDB item via AWS Console to trigger a MODIFY stream event

**Expected:** Notification Lambda invoked but skips record — logs show `Skipping event: MODIFY`
**Actual:** CloudWatch log shows `Skipping event: MODIFY` ✅
**Result:** ✅ Pass — INSERT filter working correctly, no duplicate emails on updates

---

## Sprint 4: S3 + CloudFront Frontend Testing

**Date:** 2026-02-25

### Test 1: CloudFront distribution deployment

**Method:** `terraform apply` — verified CloudFront distribution created successfully

**Expected:** Distribution created, domain name returned in outputs
**Actual:**
```
cloudfront_domain_name = "d1ofpswor88kom.cloudfront.net"
api_endpoint = "https://aspfcar444.execute-api.eu-central-1.amazonaws.com/prod/submit"
```
**Result:** ✅ Pass

### Test 2: S3 bucket access block verification

**Method:** AWS Console → S3 → adventureconnect-contact-form-bucket-rh → Permissions

**Expected:** All four public access block settings enabled
**Actual:** Block all public access: On ✅
**Result:** ✅ Pass

### Test 3: Static website load via CloudFront

**Method:** Opened CloudFront URL in browser after uploading index.html

**Command:**
```bash
aws s3 cp frontend/index.html s3://adventureconnect-contact-form-bucket-rh/index.html --region eu-central-1
```

**Expected:** AdventureConnect contact form rendered in browser
**Actual:** Page loaded correctly — two-panel layout, form fields visible, AdventureConnect branding ✅
**Result:** ✅ Pass

### Test 4: Full end-to-end browser submission

**Method:** Filled in form via browser at CloudFront URL, clicked Send Message

**Test Data:**
- Name: Robert Robertovic
- Email: robertovo@robert.robik
- Message: Banik pyco!

**Expected:**
- Success message displayed in browser
- DynamoDB record written
- Email received at robik.horvath@gmail.com

**Actual:**
- Browser: Success message displayed ✅
- Email received — Submission ID: 8fb6bb93-e9f3-4e34-a0e6-91e08a9469c6, Timestamp: 2026-02-25T08:24:46.912831 ✅
- Sender: akkina.trifer@gmail.com ✅

**Result:** ✅ Pass

### Test 5: Direct S3 URL access (security verification)

**Method:** Attempted to access S3 bucket URL directly bypassing CloudFront

**Expected:** 403 Access Denied — bucket is private, OAC restricts access
**Actual:** 403 Access Denied ✅
**Result:** ✅ Pass

---

## Sprint 5: CloudWatch Monitoring & Alerts Testing

**Date:** 2026-03-01

### Test 1: CloudWatch alarms deployment

**Method:** `terraform apply` — verified all alarms created successfully

**Expected:** 8 alarms created, all in OK or INSUFFICIENT_DATA state
**Actual:**
```bash
aws cloudwatch describe-alarms --region eu-central-1 --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}' --output table
```
All 8 alarms created ✅
**Result:** ✅ Pass

### Test 2: SNS subscription confirmation

**Method:** Clicked confirmation link in SNS subscription email after `terraform apply`

**Expected:** Subscription status changes from PendingConfirmation to Confirmed
**Actual:** Subscription confirmed ✅
**Result:** ✅ Pass

**Note:** This step is easy to miss — alerts are silently dropped until confirmation is clicked.

### Test 3: CloudWatch dashboard verification

**Method:** AWS Console → CloudWatch → Dashboards → adventureconnect-dashboard

**Expected:** 8 widgets visible, grouped by service (Lambda, API Gateway, DynamoDB)
**Actual:**
- Lambda Errors widget — both functions visible ✅
- Lambda Duration widget — data point at 241ms ✅
- Lambda Invocations widget — contact handler and notification handler visible ✅
- API Gateway Latency widget — data visible ✅
- API Gateway 5XX Errors widget — data visible ✅
- API Gateway 4XX Errors widget — data visible ✅
- DynamoDB System Errors widget — visible ✅
- DynamoDB Throttled Requests widget — visible ✅

**Result:** ✅ Pass

### Test 4: Full end-to-end test with dashboard verification

**Method:** Browser form submission at CloudFront URL, verified metrics updated in dashboard

**Test Data:**
- Name: Robert Horvath
- Email: robert@horvath.com
- Message: Hello, this is a test message for Lambda and DynamoDB table.

**Expected:**
- Form submission succeeds
- DynamoDB record written — Submission ID: 8fb81e5b-bb1d-4476-8145-5d8a0203281a, Timestamp: 2026-03-01T20:08:42.013921
- Email received
- Lambda Invocations metric increments in dashboard
- Lambda Duration shows ~241ms warm start

**Actual:**
- All fields confirmed in DynamoDB scan ✅
- Email delivered with correct submission ID and timestamp ✅
- Lambda Duration: 241ms (well under 1000ms alarm threshold) ✅
- Lambda Invocations: both contact handler and notification handler showing ✅

**Result:** ✅ Pass — full stack operational with monitoring