//
//	MessageTextView.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/07/07.
//

import SwiftUI

@Observable
class TextContent: Equatable {
	static let pathExtension = "txt"
	let key: String
	var text: String
	init(key: String, text: String) {
		self.key = key
		self.text = text
	}
	var data: Data {
		return self.text.data(using: .utf8) ?? Data()
	}
	static func == (lhs: TextContent, rhs: TextContent) -> Bool {
		return lhs.key == rhs.key
	}
}


struct TextContentView: View {
	static let pathExtension = "txt"
	let session: ServiceManager.Session
	@Binding var textContent: TextContent?
	@Binding var error: Error?
	@State var taskCount = 0
	@State var text: String = "New York"
	@FocusState var isFocused: Bool
	init(session: ServiceManager.Session, textContent: Binding<TextContent?>, error: Binding<Error?>) {
		self.session = session
		self._textContent = textContent
		self._error = error
	}
	var body: some View {
		VStack {
			if self.textContent != nil {
				TextEditor(text: $text)
					.focused($isFocused)
			}
			else {
				ContentUnavailableView("No content", image: "line.3.horizontal")
			}
			HStack {
				Spacer()
			}
			.frame(height: 20)
			.foregroundStyle(.secondary)
		}
		.onChange(of: self.textContent, { oldValue, newValue in
			self.text = newValue?.text ?? ""
		})
		.toolbar {
			if self.textContent != nil {
				Button { self.revert() } label: { Text("Revert") }
				Button { self.save() } label: { Text("Save") }
			}
		}
		.overlay {
			if self.taskCount > 0 {
				ProgressView()
					.progressViewStyle(.circular)
			}
		}
		.padding()
	}
	private func revert() {
		if let textContent = self.textContent {
			self.text = textContent.text
			self.isFocused = false
		}
	}
	private func save() {
		if let textContent = self.textContent {
			textContent.text = self.text
			self.isFocused = false
			Task {
				self.taskCount += 1
				defer { self.taskCount -= 1 }
				do { try await ServiceManager.shared.saveTextContent(session: self.session, textContent: textContent) }
				catch { self.error = error }
			}
		}
	}
}

