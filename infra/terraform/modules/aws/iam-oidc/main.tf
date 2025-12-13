data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint,
  ]

  tags = merge(
    var.tags,
    {
      Name        = "${var.name_prefix}-github-actions-oidc"
      Terraform   = "true"
      Environment = var.environment
    }
  )
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_repositories
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name_prefix}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(
    var.tags,
    {
      Name        = "${var.name_prefix}-github-actions-role"
      Terraform   = "true"
      Environment = var.environment
    }
  )
}

# Least-privilege policy for GitHub Actions
data "aws_iam_policy_document" "github_actions_permissions" {
  # ECR permissions
  dynamic "statement" {
    for_each = var.enable_ecr_permissions ? [1] : []
    content {
      sid    = "ECRPermissions"
      effect = "Allow"
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
      ]
      resources = var.ecr_repository_arns
    }
  }

  dynamic "statement" {
    for_each = var.enable_ecr_permissions ? [1] : []
    content {
      sid    = "ECRGetAuthorizationToken"
      effect = "Allow"
      actions = [
        "ecr:GetAuthorizationToken",
      ]
      resources = ["*"]
    }
  }

  # EKS permissions
  dynamic "statement" {
    for_each = var.enable_eks_permissions ? [1] : []
    content {
      sid    = "EKSDescribeCluster"
      effect = "Allow"
      actions = [
        "eks:DescribeCluster",
      ]
      resources = var.eks_cluster_arns
    }
  }

  # S3 permissions for artifacts
  dynamic "statement" {
    for_each = var.enable_s3_permissions ? [1] : []
    content {
      sid    = "S3Permissions"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
      ]
      resources = concat(
        var.s3_bucket_arns,
        [for bucket in var.s3_bucket_arns : "${bucket}/*"]
      )
    }
  }

  # Additional custom permissions
  dynamic "statement" {
    for_each = var.additional_policy_statements
    content {
      sid       = lookup(statement.value, "sid", null)
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.name_prefix}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

# Optionally attach additional managed policies
resource "aws_iam_role_policy_attachment" "github_actions_additional" {
  for_each = toset(var.additional_managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
