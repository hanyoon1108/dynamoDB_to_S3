
# dynamoDB Example
resource "aws_dynamodb_table" "Dynamodb_test" {
  name = "test"
  read_capacity = 5
  write_capacity = 5
  hash_key = "pk"
  range_key = "sk"

   # dynamoDB stream 설정 !꼭 켜야함
  stream_enabled = true
  stream_view_type = "NEW_IMAGE"
}

/**
 dynamoDB stream
*/
// Lambda to firehose

//lambda role
resource "aws_iam_role" "dynamodb_to_firehose_role" {
  name = "dynamodb-to-firehose-role"
  description = "DynamoBD data from lambda to s3 firehose role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

//lambda policy
resource "aws_iam_policy" "dynamodb_to_firehose_policy" {
  name        = "dynamodb-to-firehose-policy"
  description = "DynamoBD data from lambda to s3 firehose policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetShardIterator",
                "dynamodb:DescribeStream",
                "dynamodb:GetRecords",
                "dynamodb:ListStreams"
            ],
            "Resource": "${aws_dynamodb_table.Dynamodb_test.arn}/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "firehose:*"
            ],
            "Resource": "${aws_kinesis_firehose_delivery_stream.firehose_dyanamodb_to_s3.arn}"
        }
    ]
}
EOF
}

// Lambda policy attach
resource "aws_iam_role_policy_attachment" "lambda_ab_test_policy_attach" {
  policy_arn = aws_iam_policy.dynamodb_to_firehose_policy.arn
  role       = aws_iam_role.dynamodb_to_firehose_role.name
}

// Lambda
resource "aws_lambda_function" "lambda_dynamodb_to_firehose" {
  function_name = "lambda-dynamodb-to-firehose"
  role          = aws_iam_role.dynamodb_to_firehose_role.arn

  # stream_lambda path
  s3_bucket = aws_s3_bucket.log_bucket.bucket
  s3_key    = "function/test/stream_lambda.zip"
  handler       = "dynamodb_cdc.lambda_handler"

  runtime = "python3.8"
  timeout       = 5
  memory_size   = 128
  reserved_concurrent_executions = 5

  environment {
    variables = {
      DeliveryStreamName =	aws_kinesis_firehose_delivery_stream.firehose_dyanamodb_to_s3.name
    }
  }
}

// lambda trigger
resource "aws_lambda_event_source_mapping" "dynamodb_to_firehose_source" {
  event_source_arn  = aws_dynamodb_table.Dynamodb_test.stream_arn
  function_name     = aws_lambda_function.lambda_dynamodb_to_firehose.arn
  batch_size        = 100
  starting_position = "TRIM_HORIZON"
}

// Firehose role
resource "aws_iam_role" "firehose_from_dynamodb_to_s3_role" {
  name = "firehose-from-dynamodb-to-s3-role"
  description = "Firehose dynamodb data to s3"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

// Firehose policy
resource "aws_iam_policy" "firehose_from_dynamodb_to_s3_policy" {
  name        = "firehose-from-dynamodb-to-s3-policy"
  description = "Firehose dynamodb data to s3"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucketMultipartUploads",
                "s3:AbortMultipartUpload",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${aws_s3_bucket.log_bucket.arn}/*"
            ]
        }
    ]
}
EOF
}

// Firehose policy attach
resource "aws_iam_role_policy_attachment" "firehose_ab_test_policy_attach" {
  policy_arn = aws_iam_policy.firehose_from_dynamodb_to_s3_policy.arn
  role       = aws_iam_role.firehose_from_dynamodb_to_s3_role.name
}

// Firehose
resource "aws_kinesis_firehose_delivery_stream" "firehose_dyanamodb_to_s3" {
  name        = "ab-test-firehose-to-s3"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_from_dynamodb_to_s3_role.arn
    bucket_arn = aws_s3_bucket.log_bucket.arn
    prefix = "ab_test/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "error_ab_test/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/error_type=!{firehose:error-output-type}/"
    buffer_size        = 25
    buffer_interval    = 300
  }

  lifecycle {
    ignore_changes = [
      extended_s3_configuration
    ]
  }
}
