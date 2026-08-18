    AWS CloudFront + Private S3 Static Site

A Terraform project that provisions a secure, CDN-backed static site hosting setup on AWS: a private S3 bucket serving content exclusively through CloudFront via an Origin Access Identity (OAI) — no public S3 access required.

    Architecture

```
User ──► CloudFront Distribution ──► S3 Bucket (private)
              │                           ▲
              │                           │
        Origin Access Identity ───────────┘
        (only OAI can read objects)
```

    Flow:
1. A private S3 bucket stores the static site's files (HTML, CSS, JS, images)
2. All public access to the bucket is explicitly blocked at the account/bucket level
3. A CloudFront Origin Access Identity is created and granted read-only access via a bucket policy — this is the *only* way into the bucket
4. CloudFront serves content globally from edge locations, enforcing HTTPS (`redirect-to-https`)
5. Optional custom error responses route 403/404s back to `index.html` (useful for single-page apps)

   Why this pattern

Making an S3 bucket public and pointing CloudFront at its website endpoint is the common beginner approach — but it means anyone can bypass CloudFront entirely and hit S3 directly, and the bucket itself is exposed to the internet. Using a **private bucket + Origin Access Identity** instead means:
- The bucket has zero public access, even if someone finds its direct URL
- CloudFront is the only path to the content, so caching, HTTPS enforcement, and (if added later) WAF rules can't be bypassed
- This is the AWS-recommended pattern for CDN-fronted static hosting

   Tech stack

| Component | Purpose |
|---|---|
| **Terraform** | Infrastructure as Code |
| **S3** | Private origin storage for static files |
| **CloudFront** | CDN — global edge caching, HTTPS termination |
| **Origin Access Identity (OAI)** | Authenticates CloudFront to S3 without making the bucket public |
| **IAM (bucket policy)** | Grants the OAI, and only the OAI, read access |

   Project structure

```
.
└── cloudfront.tf   # Provider, S3 bucket, public access block, OAI, bucket policy, CloudFront distribution, outputs
```

    Prerequisites

- Terraform >= 1.5
- An AWS account with credentials configured (`aws configure` or environment variables)
- A globally unique S3 bucket name (edit the `bucket` value in `cloudfront.tf`)

  Setup

```bash
terraform init
terraform plan
terraform apply
```

Once applied, note the outputs:
```bash
terraform output cloudfront_domain_name   # e.g. d1234abcd.cloudfront.net
terraform output s3_bucket_name
```

   Uploading site content

This project provisions the infrastructure only — it does not upload files. Sync your static site to the bucket after applying:

```bash
aws s3 cp ./your-site s3://$(terraform output -raw s3_bucket_name) --recursive
```

CloudFront caches aggressively by default (`default_ttl = 3600`), so after updating files you may need to create an invalidation to see changes immediately:

```bash
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

   Real-world use cases

- **Static site / SPA hosting** — React, Vue, or plain HTML/CSS/JS sites served globally with low latency
- **Documentation sites** — internal or public docs that need to be fast and cheap to host
- **Portfolio/marketing pages** — no server to manage, pay only for storage + requests
- **Asset/CDN offloading** — serving images, fonts, or downloadable files for a larger application without hitting your origin servers directly

   Possible extensions

- Add a custom domain with an ACM certificate (must be issued in `us-east-1` for CloudFront)
- Add AWS WAF in front of the distribution for additional protection
- Replace `forwarded_values` with a modern Cache Policy (`aws_cloudfront_cache_policy`)
- Add `aws_s3_object` resources (or a CI/CD step) to automate content uploads on every deploy
- Add a CloudFront invalidation step to a deployment pipeline so updates go live immediately

   Cleanup

```bash
terraform destroy