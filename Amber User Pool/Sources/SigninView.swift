//
//	SigninView.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/07/07.
//

import SwiftUI

struct SigninView: View {

	let serviceManager = ServiceManager.shared
	@Binding var navigationPath: NavigationPath
	@State private var email: String = ""
	@State private var password: String = ""
	@State private var message: String?
	@State private var taskCount = 0
	var body: some View {
		VStack {
			Form {
				Section("Amber User Pool: Sign-in") {
					TextField("email", text: $email)
					SecureField("password", text: $password)
					if let message {
						Text(message)
							.textSelection(.enabled)
					}
					Button {
						self.signin(email: self.email, password: self.password)
					} label: {
						Text("Signin")
					}
					.buttonStyle(BorderedProminentButtonStyle())
				}
				.padding(.horizontal)
			}
			.listRowSeparator(.hidden)
			#if os(iOS)
			.frame(width: 300, height: 200)
			#elseif os(macOS)
			.frame(width: 300, height: 140)
			#endif
			.overlay {
				if self.taskCount > 0 {
					ProgressView()
						.progressViewStyle(.circular)
				}
			}
			.background(.white)
		}
	}
	private func signin(email: String, password: String) {
		Task {
			taskCount += 1
			defer { taskCount -= 1 }
			do {
				let session = try await self.serviceManager.signin(email: email, password: password)
				self.navigationPath.append(session)
			}
			catch {
				self.message = "\(error)"
			}
		}
	}
}

