provider "aws" {
  region = "ap-south-1"
}


# Bucket for storing CSV files
resource "aws_s3_bucket" "csv_bucket" {
  bucket = "csv-bucket-jenkins-unique-66"
}

# Send events to this event bus using S3 notification
resource "aws_s3_bucket_notification" "csv_bucket_notification" {
  bucket = aws_s3_bucket.csv_bucket.id

  eventbridge = true

}

# Creating DynamoDB table
resource "aws_dynamodb_table" "colors_table" {
  name           = "colors"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "Name"
  range_key      = "HEX"

  attribute {
    name = "Name"
    type = "S"
  }

  attribute {
    name = "HEX"
    type = "S"
  }
}

# Assume role policy for Lambda
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Creating IAM role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_execution_role_dynamo_s3"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Creating policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name = "custom_lambda_s3_dynamo_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
          # "logs:*"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:ListBucket",
          # "s3:*"
        ],
        "Resource" : [
          "${aws_s3_bucket.csv_bucket.arn}/*",
          aws_s3_bucket.csv_bucket.arn
        ]
      }
    ]
  })
}

# Attach policies to Lambda execution role
resource "aws_iam_policy_attachment" "lambda_dynamodb_policy_attachment" {
  name       = "lambda_dynamodb_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_policy_attachment" "lambda_custom_policy_attachment" {
  name       = "lambda_custom_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = aws_iam_policy.lambda_policy.arn
}



# Lambda function to process the events
resource "aws_lambda_function" "csv_to_dynamo_function" {
  filename      = "fun.zip"
  function_name = "s3todynamo"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "s3todynamo.lambda_handler"
  runtime       = "python3.8"

}


# Event Rule for default bus
resource "aws_cloudwatch_event_rule" "s3_event_rule" {
  name = "s3_dynamo_rule_1"
  # role_arn = aws_iam_role.eventbridge_lambda_invocation_role.arn
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.csv_bucket.bucket]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_event_target" {
  rule = aws_cloudwatch_event_rule.s3_event_rule.name
  arn  = aws_lambda_function.csv_to_dynamo_function.arn
}





#Adding trigger to lambda for eventbridge rule
resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_to_dynamo_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_event_rule.arn
}

