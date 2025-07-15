plugin "aws" {
  enabled = true
  region = "us-east-1"
}
 
rule "terraform_version" {
  enabled = true
  version = ">= 1.0"
}
 
rule "aws_s3_bucket_versioning" {
  enabled = true
  message = "S3 buckets must have versioning enabled."
  check = { 
    resource = "aws_s3_bucket"
    key      = "versioning"
    value    = "Enabled"
  }
}
