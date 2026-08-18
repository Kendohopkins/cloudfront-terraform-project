# Uploads every file in ./site/ to the S3 bucket, setting the correct
# Content-Type for each based on its extension (important — without this,
# browsers may refuse to render HTML/CSS/JS correctly, since S3 defaults
# everything to application/octet-stream).

resource "aws_s3_object" "site_files" {
  for_each = fileset("${path.module}/site", "**")

  bucket       = aws_s3_bucket.my_bucket.id
  key          = each.value
  source       = "${path.module}/site/${each.value}"
  etag         = filemd5("${path.module}/site/${each.value}")
  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      json = "application/json"
      png  = "image/png"
      jpg  = "image/jpeg"
      jpeg = "image/jpeg"
      svg  = "image/svg+xml"
      ico  = "image/x-icon"
    },
    lower(split(".", each.value)[length(split(".", each.value)) - 1]),
    "application/octet-stream"
  )
}
