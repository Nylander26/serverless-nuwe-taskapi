// PROVIDER CONFIGURATION
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    events         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    s3             = "http://localhost:4566"
  }
}

// BUCKET
resource "aws_s3_bucket" "taskstorage" {
    bucket = "taskstorage"
	force_destroy = true
}

// ROLE
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      "Sid": ""
    }]
  })
}

// POLICIES
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging_policy"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "arn:aws:logs:*:*:*",
        Effect   = "Allow",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_policy" "lambda_s3_access" {
  name = "lambda_s3_access_policy"
  description = "IAM policy for accessing S3 from a lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "s3:PutObject",
      Resource = "arn:aws:s3:::taskstorage/*",
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

// DYNAMODB
resource "aws_dynamodb_table" "nuwe_table" {
  name           = "taskapi"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "task_id"

  attribute {
    name = "task_id"
    type = "S"
  }
}

// INSTALL NPM DEPENDENCIES
resource "null_resource" "install_dependencies" {
	provisioner "local-exec" {
	  command = "cd ${path.module}/../lambda && npm install"
	}

	triggers = {
	  always_run = "${timestamp()}"
	}
}

// ZIP LAMBDA FUNCTIONS
data "archive_file" "create_scheduled_task_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../zip-lambdas/createScheduledTask.zip"
  excludes = [
    "node_modules",
    "package.json",
    "package-lock.json",
    "README.md",
    "executeScheduledTask.js",
    "listScheduledTask.js"
  ]
}

data "archive_file" "list_scheduled_task_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../zip-lambdas/listScheduledTask.zip"
  excludes = [
    "node_modules",
    "package.json",
    "package-lock.json",
    "README.md",
    "executeScheduledTask.js",
    "createScheduledTask.js"
  ]
}

data "archive_file" "execute_scheduled_task_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../zip-lambdas/executeScheduledTask.zip"
  excludes = [
    "node_modules",
    "package.json",
    "package-lock.json",
    "README.md",
    "createScheduledTask.js",
    "listScheduledTask.js"
  ]
}

// LAMBDA FUNCTIONS
resource "aws_lambda_function" "create_scheduled_task" {
  function_name    = "createScheduledTask"
  filename         = data.archive_file.create_scheduled_task_zip.output_path
  handler          = "createScheduledTask.handler"
  runtime          = "nodejs16.x"
  role             = aws_iam_role.lambda_exec.arn
  source_code_hash = data.archive_file.create_scheduled_task_zip.output_base64sha256
  depends_on = [ null_resource.install_dependencies, data.archive_file.create_scheduled_task_zip ]
  timeout          = 60
}

resource "aws_lambda_function" "list_scheduled_task" {
  function_name = "listScheduledTask"
  filename      = data.archive_file.list_scheduled_task_zip.output_path
  handler       = "listScheduledTask.handler"
  runtime       = "nodejs16.x"
  role          = aws_iam_role.lambda_exec.arn
  source_code_hash = data.archive_file.list_scheduled_task_zip.output_base64sha256
  depends_on = [ null_resource.install_dependencies, data.archive_file.list_scheduled_task_zip ]
  timeout       = 60
}

resource "aws_lambda_function" "execute_scheduled_task" {
  function_name = "executeScheduledTask"
  filename      = data.archive_file.execute_scheduled_task_zip.output_path
  handler       = "executeScheduledTask.handler"
  runtime       = "nodejs16.x"
  role          = aws_iam_role.lambda_exec.arn
  source_code_hash = data.archive_file.execute_scheduled_task_zip.output_base64sha256
  depends_on = [ null_resource.install_dependencies, data.archive_file.execute_scheduled_task_zip ]
  timeout       = 60
}

// CLOUDWATCH EVENT RULES AND TARGET
resource "aws_cloudwatch_event_rule" "every_minute" {
  name = "every_minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "execute_scheduled_task" {
  rule = aws_cloudwatch_event_rule.every_minute.name
  arn = aws_lambda_function.execute_scheduled_task.arn
  target_id = "executeScheduledTask"
}

// LAMBDA PERMISSIONS
resource "aws_lambda_permission" "allow_event_bridge" {
  statement_id = "AllowExecutionFromEventBridge"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.execute_scheduled_task.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.every_minute.arn
}

// API GATEWAY
resource "aws_api_gateway_rest_api" "TaskAPI" {
  name        = "TaskAPI"
  description = "This is my API for demonstration purposes"
}

// LIST TASK RESOURCE
resource "aws_api_gateway_resource" "list_task" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  parent_id   = aws_api_gateway_rest_api.TaskAPI.root_resource_id
  path_part   = "listtask"
}

resource "aws_api_gateway_method" "list_task_get" {
  rest_api_id   = aws_api_gateway_rest_api.TaskAPI.id
  resource_id   = aws_api_gateway_resource.list_task.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_task_lambda" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  resource_id = aws_api_gateway_resource.list_task.id
  http_method = aws_api_gateway_method.list_task_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.list_scheduled_task.arn}/invocations"
}

//CREATE TASK RESOURCE
resource "aws_api_gateway_resource" "create_task" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  parent_id   = aws_api_gateway_rest_api.TaskAPI.root_resource_id
  path_part   = "createtask"
}

resource "aws_api_gateway_method" "create_task_post" {
  rest_api_id   = aws_api_gateway_rest_api.TaskAPI.id
  resource_id   = aws_api_gateway_resource.create_task.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_task_lambda" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  resource_id = aws_api_gateway_resource.create_task.id
  http_method = aws_api_gateway_method.create_task_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.create_scheduled_task.arn}/invocations"
}

// DEPLOYMENT
resource "aws_api_gateway_deployment" "TaskAPI" {
  depends_on = [
    aws_api_gateway_integration.list_task_lambda,
    aws_api_gateway_integration.create_task_lambda,
  ]
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  stage_name  = "test"

  variables = {
    last_updated = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

