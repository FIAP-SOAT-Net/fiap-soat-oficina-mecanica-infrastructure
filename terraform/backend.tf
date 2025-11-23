terraform {
  backend "s3" {
    bucket         = "smart-workshop-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "smart-workshop-terraform-locks"
  }
}
