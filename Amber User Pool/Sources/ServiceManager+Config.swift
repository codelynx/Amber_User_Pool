//
//  ServiceManager+Config.swift
//  Amber User Pool
//
//  Created by Kaz Yoshikawa on 2024/07/28.
//

import Foundation

extension ServiceManager {
	static let region = "<<YOUR_REGION>>" // eg. "ap-northeast-1"
	static let userPoolID = "<<YOUR_USER_POOL_ID>>" // eg. "ap-northeast-1_7R43qBEk1"
	static let identityPoolID = "<<YOUR_IDENTITY_ID>>" // eg. "ap-northeast-1:41d41301-fcdf-4ef6-8a6e-de24167b8dc5"
	static let bucket = "<<YOUR_BUCKET>>" // eg. "amber-user-pool-bucket"
	static let appClientID = "<<YOUR_APP_CLIENT_ID>>" // eg. "2m2u617er4kjig9ar9k0qhnaaq"
	static let tokenURL = URL(string: "<<YOUR_TOKEN_URL>>")! // eg. "https://amber-user-pool.auth.ap-northeast-1.amazoncognito.com/oauth2/token"
	static let signinRedirectURL = "<<YOUR_SIGNIN_REDIRECT_URL>>" // eg. "amber-user-pool-app://auth/callback/signin"
	static let customScheme = "<<YOUR_CUSTOM_SCHEME>>" // eg. "amber-user-pool-app"
}
