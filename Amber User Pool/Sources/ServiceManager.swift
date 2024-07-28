//
//	ServiceManager.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/07/07.
//

import Foundation
import AWSClientRuntime
import AWSSDKIdentity
import AWSCognitoIdentity
import AWSCognitoIdentityProvider
import Smithy
import SmithyIdentity
import AWSS3
import CryptoKit
import SmithyHTTPAPI


extension String: Error {
}

class ServiceManager {

	typealias MD5 = Data
	struct Token {
		let identityId: String
		let accessToken: String
		let idToken: String
		let refreshToken: String
		let expires: Date
		let sub: String
		let email: String
		init?(identityId: String, accessToken: String?, idToken: String?, refreshToken: String?) {
			guard
				let accessToken = accessToken,
				let idToken = idToken,
				let refreshToken = refreshToken
			else { return nil }
			self.identityId = identityId
			self.accessToken = accessToken
			self.idToken = idToken
			self.refreshToken = refreshToken

			guard let jwt = try? Self.decodeJWT(token: idToken)
			else { return nil }
			
			guard
				let sub = jwt["sub"] as? String,
				let email = jwt["email"] as? String,
				let exp = jwt["exp"] as? Int
			else { return nil }
			self.sub = sub
			self.email = email
			self.expires = Date(timeIntervalSince1970: TimeInterval(exp))
		}
		static func decodeJWT(token: String) throws -> [String: Any] {
			enum JWTError: Error {
				case invalidToken
				case decodingFailed
			}
			let segments = token.split(separator: ".")
			guard segments.count == 3 else {
				throw JWTError.invalidToken
			}
			func decodeBase64Url(_ string: String) -> Data? {
				var base64 = string
					.replacingOccurrences(of: "-", with: "+")
					.replacingOccurrences(of: "_", with: "/")
				let paddingLength = 4 - base64.count % 4
				if paddingLength < 4 {
					base64.append(contentsOf: repeatElement("=", count: paddingLength))
				}
				return Data(base64Encoded: base64)
			}
			guard let payloadData = decodeBase64Url(String(segments[1]))
			else { throw JWTError.decodingFailed }
			guard let json = try? JSONSerialization.jsonObject(with: payloadData, options: []), let payload = json as? [String: Any]
			else { throw JWTError.decodingFailed }
			return payload
		}
		var hasExpired: Bool {
			return Date() >= self.expires
		}
	}
	struct Credentials {
		let accessKeyId: String
		let secretKey: String
		let sessionToken: String
		let expiration: Date
		init?(credentials: CognitoIdentityClientTypes.Credentials?) {
			guard
				let credentials = credentials,
				let accessKeyId = credentials.accessKeyId,
				let secretKey = credentials.secretKey,
				let sessionToken = credentials.sessionToken,
				let expiration = credentials.expiration
			else { return nil }
			self.accessKeyId = accessKeyId
			self.secretKey = secretKey
			self.sessionToken = sessionToken
			self.expiration = expiration
		}
	}
	class Session: Hashable {
		init(token: Token, serviceManager: ServiceManager) {
			self.token = token
			self.serviceManager = serviceManager
		}
		deinit {
		}
		private var _s3client: S3Client?
		var s3client: S3Client {
			get async throws {
				if let s3client = self._s3client {
					if self.token.hasExpired {
						guard let token = try await serviceManager.refreshToken(self.token)
						else { throw "failed refresh token" }
						self.token = token
					}
					else {
						return s3client
					}
				}
				let s3client = try await self.serviceManager.makeS3Client(from: self.token)
				self._s3client = s3client
				return s3client
			}
		}
		unowned let serviceManager: ServiceManager
		var email: String { return self.token.email }
		var sub: String { return self.token.sub }
		var token: Token
		func hash(into hasher: inout Hasher) {
			hasher.combine(email)
		}
		static func == (lhs: Session, rhs: Session) -> Bool {
			return lhs.email == rhs.email
		}
	}
	class Object: Hashable, Identifiable {
		let key: String
		let hash: Data
		let lastModified: Date
		init?(_ object: S3ClientTypes.Object) {
			guard
				let key = object.key, (key as NSString).pathExtension == TextContentView.pathExtension,
				let eTag = object.eTag,
				let hash = eTag.trimmingQuoteCharactors().hexadecimalData,
				let lastModified = object.lastModified
			else { return nil }
			self.key = key
			self.hash = hash
			self.lastModified = lastModified
		}
		var filename: String {
			return (self.key as NSString).lastPathComponent
		}
		var id: String {
			return self.key
		}
		func hash(into hasher: inout Hasher) {
			hasher.combine(self.key)
		}
		static func == (lhs: Object, rhs: Object) -> Bool {
			return lhs === rhs
		}
	}
	/*
	let region = "ap-northeast-1"
	let userPoolID = "ap-northeast-1_7R43qBEk1"
	let identityPoolID = "ap-northeast-1:41d41301-fcdf-4ef6-8a6e-de24167b8dc5"
	let bucket = "amber-user-pool-bucket"
	let appClientID = "2m2u617er4kjig9ar9k0qhnaaq"
	let tokenURL = URL(string: "https://amber-user-pool.auth.ap-northeast-1.amazoncognito.com/oauth2/token")!
	let signinRedirectURL = "amber-user-pool-app://auth/callback/signin"
	let customScheme = "amber-user-pool-app"
	*/
	static let shared = ServiceManager()
	private init() {
	}

	func signin(email: String, password: String) async throws -> Session {
		let authParameters: [String: String] = [
			"USERNAME": email,
			"PASSWORD": password
		]
		let identityProviderClient = try CognitoIdentityProviderClient(region: Self.region)
		guard let result = try await identityProviderClient.initiateAuth(input: InitiateAuthInput(authFlow: .userPasswordAuth, authParameters: authParameters, clientId: Self.appClientID)).authenticationResult
		else { throw "Failed to get token" }
		guard let idToken = result.idToken, let identityId = try await self.getIdentityId(with: idToken)
		else { throw "Failed to get identity ID" }
		
		guard let token = Token(identityId: identityId, accessToken: result.accessToken, idToken: result.idToken, refreshToken: result.refreshToken)
		else { throw "Failed to get token" }
		print("Signin Token: \(token)") // Log the token
		let credentials = try await self.getAWSCredentials(with: token.idToken)
		print("Signin Credentials: \(String(describing: credentials))") // Log the credentials
		return Session(token: token, serviceManager: self)
	}
	func makeS3Client(from token: Token) async throws -> S3Client {
		let cognitoIdentityClient = try CognitoIdentityClient(region: Self.region)
		let logins: [String: String] = [
			"cognito-idp.\(Self.region).amazonaws.com/\(Self.userPoolID)": token.idToken
		]
		let getIdResponse = try await cognitoIdentityClient.getId(input: GetIdInput(identityPoolId: Self.identityPoolID, logins: logins))
		guard let identityId = getIdResponse.identityId
		else { throw "Failed to get identity ID." }

		let output2 = try await cognitoIdentityClient.getCredentialsForIdentity(input: GetCredentialsForIdentityInput(identityId: identityId, logins: logins))
		guard let credentials = Credentials(credentials: output2.credentials)
		else { throw "Failed to get credentials" }

		let identity = AWSCredentialIdentity(accessKey: credentials.accessKeyId, secret: credentials.secretKey, sessionToken: credentials.sessionToken)
		let resolver = try StaticAWSCredentialIdentityResolver(identity)
		let configuration = try await S3Client.S3ClientConfiguration(awsCredentialIdentityResolver: resolver, region: Self.region)
		let s3Client = S3Client(config: configuration)
		return s3Client
	}
	private func refreshToken(_ token: Token) async throws -> Token? {
		let client = try CognitoIdentityProviderClient(region: Self.region)
		let authParameters = [
			"REFRESH_TOKEN": token.refreshToken
		]
		guard let result = try await client.initiateAuth(input: InitiateAuthInput(authFlow: .refreshToken, authParameters: authParameters, clientId: Self.appClientID)).authenticationResult
		else { return nil }
		guard let newToken = Token(identityId: token.identityId, accessToken: result.accessToken, idToken: result.idToken, refreshToken: result.refreshToken ?? token.refreshToken)
		else { return nil }
		return newToken
	}
	func listTextContents(session: Session) async throws -> [Object] {
		let prefix = "home/\(session.token.identityId)/"
		print(self.self, #function, "prefix=", prefix)
		let contents = try await session.s3client.listObjectsV2(input: ListObjectsV2Input(bucket: Self.bucket, delimiter: "/", prefix: prefix)).contents ?? []
		return contents.compactMap { Object($0) }
	}
	private func randomText() -> String {
		return [
			"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
			"Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
			"Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
			"Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
		].randomElement()!
	}
	func addTextContent(session: Session) async throws -> Object? {
		let key = "home/\(session.token.identityId)/\(UUID().uuidString).\(TextContent.pathExtension)"
		let textContent = TextContent(key: key, text: self.randomText())
		try await self.saveTextContent(session: session, textContent: textContent)
		
		let object = try await session.s3client.listObjectsV2(input: ListObjectsV2Input(bucket: Self.bucket, delimiter: "/", prefix: key)).contents?.first
		return object.flatMap { Object($0) }
	}
	func saveTextContent(session: Session, textContent: TextContent) async throws {
		_ = try await session.s3client.putObject(input: PutObjectInput(body: ByteStream.data(textContent.data), bucket: Self.bucket, key: textContent.key))
	}
	func loadTextContent(session: Session, key: String) async throws -> TextContent? {
		let output = try await session.s3client.getObject(input: GetObjectInput(bucket: Self.bucket, key: key, responseCacheControl: "max-age=2"))
		guard let data = try await output.body?.readData()
		else { return nil }
		let text = String(data: data, encoding: .utf8) ?? ""
		let textContent = TextContent(key: key, text: text)
		return textContent
	}
	func deleteObject(session: Session, key: String) async throws {
		_ = try await session.s3client.deleteObject(input: DeleteObjectInput(bucket: Self.bucket, key: key))
	}
	func getObject(session: Session, s3Key: String) async throws -> String? {
		do {
			let result = try await session.s3client.getObject(input: GetObjectInput(bucket: Self.bucket, key: s3Key, responseCacheControl: "max-age=2"))
			if let data = try await result.body?.readData(),
				let string = String(data: data, encoding: .utf8) {
				return string
			}
			else {
				return nil
			}
		}
		catch {
			switch error {
			case let error as AWSServiceError:
				throw error.errorCode ?? "\(error)"
			default:
				throw error
			}
		}
	}
	
	private func exchangeCodeForTokens(code: String) async throws -> Token {
		// URL for the Cognito token endpoint
		
		// Set up the request
		var request = URLRequest(url: URL(string: Self.tokenURL)!)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				
		// Body parameters
		let params = [
			"grant_type": "authorization_code",
			"client_id": Self.appClientID,
			"code": code,
			"redirect_uri": Self.signinRedirectURL
		]
		request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
		
		// Perform the network request
		let (data, response) = try await URLSession.shared.data(for: request)
		
		// Check for response status code
		guard let httpResponse = response as? HTTPURLResponse
		else { throw "Failed to exchange code for tokens: invalid http response" }
		guard httpResponse.statusCode == 200
		else { throw "Failed to exchange code for tokens: Invalid response: code=\(httpResponse.statusCode)" }

		// Parse the response
		if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
			if	let id_token = json["id_token"] as? String,
				let access_token = json["access_token"] as? String,
				let refresh_token = json["refresh_token"] as? String,
				let identityId = try await self.getIdentityId(with: id_token),
				let token = Token(identityId: identityId, accessToken: access_token, idToken: id_token, refreshToken: refresh_token) {
				return token
			}
			else {
				throw NSError(domain: "\(Self.self)", code: 101, userInfo: [
					NSLocalizedDescriptionKey: "insufficient token",
					"json": json
				])
			}
		}
		else {
			throw "\(Self.self) \(#function): response for the code is not a json."
		}
	}
	private func getIdentityId(with idToken: String) async throws -> String? {
		let configuration = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(region: Self.region)
		let identityClient = CognitoIdentityClient(config: configuration)
		let logins: [String: String] = [
			"cognito-idp.\(Self.region).amazonaws.com/\(Self.userPoolID)": idToken
		]
		let request = GetIdInput(identityPoolId: Self.identityPoolID, logins: logins)
		let response = try await identityClient.getId(input: request)
		return response.identityId
	}
	func getAWSCredentials(with idToken: String) async throws -> Credentials? {
		let identityId = try await self.getIdentityId(with: idToken)
		assert(identityId != nil)
		let configuration = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(region: Self.region)
		let identityClient = CognitoIdentityClient(config: configuration)
		let logins:  [String: String] = [
			"cognito-idp.\(Self.region).amazonaws.com/\(Self.userPoolID)": idToken
		]
		let request = GetCredentialsForIdentityInput(customRoleArn: nil, identityId: identityId, logins: logins)
		let response = try await identityClient.getCredentialsForIdentity(input: request)
		return response.credentials.flatMap { Credentials(credentials: $0) }
	}
	func handleCognitoRedirect(url: URL) async throws -> Session? {
		let components: URLComponents? = URLComponents(url: url, resolvingAgainstBaseURL: true)
		if components?.scheme?.lowercased() == Self.customScheme.lowercased() {
			if components?.path.lowercased() == "/callback/signin" {
				if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value {
					let token = try await self.exchangeCodeForTokens(code: code)
					print("Callback Token: \(token)") // Log the token
					let credentials = try await self.getAWSCredentials(with: token.idToken)
					print("Callback Credentials: \(String(describing: credentials))") // Log the credentials
					return Session(token: token, serviceManager: self)
				}
			}
		}
		return nil
	}
	func signout(session: Session) async throws {
		let client = try CognitoIdentityProviderClient(region: Self.region)
		_ = try await client.globalSignOut(input: GlobalSignOutInput(accessToken: session.token.accessToken))
	}
}
