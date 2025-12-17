terraform {
  backend "s3" {
    bucket         = "smart-workshop-infrastructure-terraform-state-243100982781"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "smart-workshop-terraform-locks-243100982781"
  }
}
