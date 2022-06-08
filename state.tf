######################## Pre-requisite - Start #########################
/*
# Start - Once execute need to be disable
# tf init
# tf apply --auto-approve
# From output please update line 7 and line 9 value , it will required in future for delete.
# Cleanup Script : rm -rf .terraform* terraform.tfstate*
# >>>>>>>>>>>>>>> Delete Steps below >>>>>>>>>>>>>>>
# tf init
# tf import aws_s3_bucket.s3_backend_bucket terraform-state-20220514033459483100000001
# tf import aws_dynamodb_table.s3_backend_bucket_state_locking dynamodb-state-locking
# tf import aws_kms_key.s3_backend_kms_key 573a3eec-dab7-4910-b21c-4a1a7d759225
# tf import aws_kms_alias.s3_backend_kms_alias alias/terraform-state
# tf destroy --auto-approve
# rm -rf .terraform* | rm -rf terraform.tfstate* | rm -rf pre-requisite-output.note

resource "aws_s3_bucket" "s3_backend_bucket" {
  bucket_prefix = "${var.bucket_name}-"

  tags = {
    Name        = var.bucket_name
    Type        = "Terraform-Automation"
    Environment = "Shared"
  }
}
resource "aws_s3_bucket_acl" "s3_backend_bucket_acl" {
  bucket = aws_s3_bucket.s3_backend_bucket.id
  acl    = "private"
}
resource "aws_dynamodb_table" "s3_backend_bucket_state_locking" {
  hash_key = "LockID"
  name     = "dynamodb-state-locking"
  attribute {
    name = "LockID"
    type = "S"
  }
  billing_mode = "PAY_PER_REQUEST"
}
resource "aws_s3_bucket_versioning" "s3_backend_bucket_versioning" {
  bucket = aws_s3_bucket.s3_backend_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_kms_key" "s3_backend_kms_key" {}
resource "aws_kms_alias" "s3_backend_kms_alias" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.s3_backend_kms_key.key_id
}

output "S3BucketName" {
  value = aws_s3_bucket.s3_backend_bucket.bucket_domain_name
  description ="Please update this name into state bucket name section"
}
output "s3_backend_kms_key" {
  value = aws_kms_key.s3_backend_kms_key.key_id
  description = "Please Keep the id , it required to import ref : line 6"
}
*/
######################## Pre-requisite - END #########################

##################################################################
######################## Operation START #########################
##################################################################

terraform {
  backend "s3" {
    bucket         = "terraform-state-20220514034811212300000001"
    key            = "ecs-cluster"
    # https://www.terraform.io/language/settings/backends/s3
    # Notes : Amazon S3 > Buckets > terraform-state > env:/ dev/ > ecs-cluster
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "dynamodb-state-locking"
    kms_key_id     = "alias/terraform-state"
  }
}

