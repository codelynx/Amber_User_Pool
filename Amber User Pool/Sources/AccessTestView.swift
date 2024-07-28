//
//	AccessTestView.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/07/20.
//

import SwiftUI

struct AccessTestView: View {
	let session: ServiceManager.Session
	@State var s3key = "private/README.txt"
	@State var text: String?
	@State var taskCount = 0
	@State var error: Error?
	var body: some View {
		VStack {
			HStack {
				TextField("s3 key", text: $s3key)
				Button(action: {
					self.accessTest()
				}, label: {
					Text("Access Test")
				})
			}
			if let text {
				TextEditor(text: .constant(text))
			}
			else {
				Spacer()
			}
		}
		.overlay {
			if self.taskCount > 0 {
				ProgressView()
					.progressViewStyle(.circular)
			}
		}
		.alert("Error", isPresented: .constant(self.error != nil), presenting: error) { error in
			Button("OK", action: {})
		} message: { error in
			VStack {
				Image(systemName: "exclamationmark.triangle")
				Text("\(error)")
			}
			.padding()
		}

	}
	private func accessTest() {
		Task {
			self.taskCount += 1
			defer { self.taskCount -= 1 }
			do {
				self.text = try await ServiceManager.shared.getObject(session: self.session, s3Key: self.s3key)
			}
			catch {
				self.error = error
			}
		}
	}
}
