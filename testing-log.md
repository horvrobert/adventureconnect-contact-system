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

**Execution time:** ~200ms (warm start - function already initialized from previous test)

**What I learned:**
- Lambda-DynamoDB integration works with proper IAM permissions
- Environment variables correctly passed to Lambda runtime
- UUID generation produces unique identifiers as expected



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
- Cold start: 714 ms (488 ms init + 225 ms execution)
- Warm start: 70 ms (0 ms init + 69 ms execution)
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

**Result:** ✅ Expected behavior - documented in errors.md (E-002)

**Fix:** Restored `aws_lambda_permission`, verified API works again