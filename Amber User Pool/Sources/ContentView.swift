//
//	ContentView.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/07/06.
//

import SwiftUI
import AWSClientRuntime
import AWSSDKIdentity
import AWSCognitoIdentity
import AWSCognitoIdentityProvider
import Smithy
import SmithyIdentity
import AWSS3


struct ContentView: View {
	enum ServiceError: Error {
		case failedInitiateAuth
		case invalidToken
	}
	struct Token {
		let accessToken: String
		let idToken: String
		let refreshToken: String
		init?(_ result: CognitoIdentityProviderClientTypes.AuthenticationResultType?) {
			guard
				let result = result,
				let accessToken = result.accessToken,
				let idToken = result.idToken,
				let refreshToken = result.refreshToken
			else { return nil }
			self.accessToken = accessToken
			self.idToken = idToken
			self.refreshToken = refreshToken
		}
	}
	struct Credentials {
		let accessKeyId: String
		let secretKey: String
		let sessionToken: String
		init?(credentials: CognitoIdentityClientTypes.Credentials?) {
			guard
				let credentials = credentials,
				let accessKeyId = credentials.accessKeyId,
				let secretKey = credentials.secretKey,
				let sessionToken = credentials.sessionToken
			else { return nil }
			self.accessKeyId = accessKeyId
			self.secretKey = secretKey
			self.sessionToken = sessionToken
		}
	}

	@State var navigationPath = NavigationPath()
	@State var items = [String]()
	@State private var selection: String?
	@State var error: Error?

	var body: some View {
		GeometryReader(content: { geometry in
			NavigationStack(path: $navigationPath) {
				VStack {
					SigninView(navigationPath: $navigationPath)
						.cornerRadius(15)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.navigationDestination(for: ServiceManager.Session.self) { session in
					TextContentSplitView(session: session, error: $error) {
						self.navigationPath.removeLast()
					}
				}
				.background(content: {
					Color.secondary
						.edgesIgnoringSafeArea(.all)
				})
			}
			.onOpenURL { url in
				self.handleURL(url)
			}
			.alert(Text("Error"), isPresented: .constant(self.error != nil), presenting: error) { error in
				Button(action: {
					self.error = nil
				}, label: {
					Text("OK")
				})
			} message: { error in
				Text("\(error)")
			}
		})
	}
	func handleURL(_ url: URL) {
		Task {
			do {
				if let session = try await ServiceManager.shared.handleCognitoRedirect(url: url) {
					self.navigationPath.append(session)
				}
			}
			catch {
				self.error = error
			}
		}
	}
}

#Preview {
	ContentView()
}
