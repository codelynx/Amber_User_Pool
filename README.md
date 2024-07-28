# Amber User Pool

## Overview

This is an experimental SwiftUI app project that demonstrates how to AWS Cognito user can sign-in and access
only to his/her home directory in S3 bucket using `${cognito-identity.amazonaws.com:sub}`.

I have provided an article here (in Japanese)

https://qiita.com/codelynx/items/7f4e2f0a0f845cc80f0f

<img src="https://camo.qiitausercontent.com/bc7cf8140b65c9033a66804c900da655925c2f36/68747470733a2f2f71696974612d696d6167652d73746f72652e73332e61702d6e6f727468656173742d312e616d617a6f6e6177732e636f6d2f302f36353633342f31626339346635622d636561382d396638642d383639352d6632626431366465366261362e706e67" />

<img width="600" src="https://camo.qiitausercontent.com/64248583112935eb728bc0b93f15668f1612e79e/68747470733a2f2f71696974612d696d6167652d73746f72652e73332e61702d6e6f727468656173742d312e616d617a6f6e6177732e636f6d2f302f36353633342f39303062643631312d363937622d333337312d313763322d6239363431313266633564642e706e67" />

## Here is the AWS configuration for this project.  You should apply your configuration over these settings. 

### User pools

| Name | Property |
|:-----------|:------------|
| User pool name | amber-user-pool |
| User pool ID | ap-northeast-1_7R43qBEk1 |
| ARN | arn:aws:cognito-idp:ap-northeast-1:566372147352:userpool/ap-northeast-1_7R43qBEk1 |
| Advanced security | Disabled |
| Cognito user pool sign-in options | Email |
| Federated identity provider sign-in | none |
| Multi-factor authentication | No MFA |
| Self-service account recovery | Enabled |
| Recovery message delivery method | Email only |
| Allow Cognito to automatically send messages to verify and confirm | Yes |
| Attributes to verify | Send email message, verify email address |
| Keep original attribute value active when an update is pending | Enabled |
| Active attribute values when an update is pending | Email address |
| Required attributes | email |
| Custom attributes | none |
| Self-registration | Enabled |
| Cognito domain | https://amber-user-pool.auth.ap-northeast-1.amazoncognito.com |


### Identity Pool

| Name | Property |
|:-----------|:------------|
| Identity pool name | amber-identity-pool |
| Identity pool ID | ap-northeast-1:41d41301-fcdf-4ef6-8a6e-de24167b8dc5 |
| Authenticated role | service-role/amber-user-pool-role |
| Authenticated role ARN | arn:aws:iam::566372147352:role/service-role/amber-user-pool-role |
| Identity provider type | Amazon Cognito user pool |
| Identity provider | ap-northeast-1_7R43qBEk1 |
| Attributes for access control | Inactive |
| Basic authentication | Inactive |


### App Integration

| Name | Property |
|:-----------|:------------|
| App client name | amber-user-pool-app-client |
| Client ID | 2m2u617er4kjig9ar9k0qhnaaq |
| Client secret | - |
| Authentication flows | ALLOW_REFRESH_TOKEN_AUTH, ALLOW_USER_PASSWORD_AUTH, ALLOW_USER_SRP_AUTH |
| Hosted UI status | Available |
| Allowed callback URLs | amber-user-pool-app://auth/callback/signin |
| Allowed sign-out URLs | amber-user-pool-app://auth/callback/signout |
| Identity providers | Cognito user pool directory |
| OAuth grant types | Authorization code grant |
| OpenID Connect scopes | aws.cognito.signin.user.admin, emailm openid |


### S3 Bucket

| Name | Property |
|:-----------|:------------|
| Bucket name | amber-user-pool-bucket |
| AWS Region | Asia Pacific (Tokyo) ap-northeast-1 |
| Amazon Resource Name (ARN) | arn:aws:s3:::amber-user-pool-bucket |


### Bucket Policy JSON

```bucket-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::566372147352:role/service-role/amber-user-pool-role"
            },
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::amber-user-pool-bucket/home/${cognito-identity.amazonaws.com:sub}/*",
                "arn:aws:s3:::amber-user-pool-bucket"
            ]
        }
    ]
}
```

### IAM > Role

| Name | Property |
|:-----------|:------------|
| Role name | amber-user-pool-role |
| ARN | arn:aws:iam::566372147352:role/service-role/amber-user-pool-role |

```Trusted relationships.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "cognito-identity.amazonaws.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "cognito-identity.amazonaws.com:aud": "ap-northeast-1:41d41301-fcdf-4ef6-8a6e-de24167b8dc5"
                },
                "ForAnyValue:StringLike": {
                    "cognito-identity.amazonaws.com:amr": "authenticated"
                }
            }
        }
    ]
}
```

```amber-user-pool-role-policy.json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AllowListingOfUserFolder",
			"Effect": "Allow",
			"Action": "s3:ListBucket",
			"Resource": "arn:aws:s3:::amber-user-pool-bucket"
		},
		{
			"Sid": "AllowUserFolderOperations",
			"Effect": "Allow",
			"Action": [
				"s3:GetObject",
				"s3:PutObject",
				"s3:DeleteObject"
			],
			"Resource": "arn:aws:s3:::amber-user-pool-bucket/home/${cognito-identity.amazonaws.com:sub}/*"
		}
	]
}
```


This project is based on following environment.

```log
macOS: 14.5 (23F79)
Xcode: Version 15.4 (15F31d)
$ swift --version
swift-driver version: 1.90.11.1 Apple Swift version 5.10 (swiftlang-5.10.0.13 clang-1500.3.9.4)
Target: arm64-apple-macosx14.0
$ aws --version
aws-cli/2.15.38 Python/3.11.8 Darwin/23.5.0 exe/x86_64 prompt/off
aws-sdk-swift: 0.46.0
```
