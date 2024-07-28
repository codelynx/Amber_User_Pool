//
//	TextContentSplitView.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/07/08.
//

import SwiftUI
import AWSS3

struct TextContentSplitView: View {
	typealias HashData = Data
	typealias Object = ServiceManager.Object
	let session: ServiceManager.Session
	@State private var items = [Object]()
	@State private var selection: Object?
	@State private var textContent: TextContent?
	@State private var taskCount = 0
	@Binding var error: Error?
	let dismiss: ()->()
	var body: some View {
		NavigationSplitView {
			if self.taskCount > 0 {
				ProgressView()
					.progressViewStyle(.circular)
			} else {
				VStack {
					if items.count > 0 {
						List(self.items, id: \.self, selection: $selection) { item in
							HStack {
								Text(item.filename)
								Spacer()
								Button(action: {
									self.deleteObject(item)
								}, label: {
									Image(systemName: "trash")
										.foregroundStyle(.foreground)
								})
								.buttonStyle(BorderlessButtonStyle())
							}
						}
					} else {
						ContentUnavailableView("No contents", systemImage: "line.3.horizontal")
					}
				}
				.contentShape(Rectangle())
				.onChange(of: self.selection, { oldValue, newValue in
					if let newValue {
						Task {
							do {
								self.textContent = try await ServiceManager.shared.loadTextContent(session: self.session, key: newValue.key)
							} catch {
								print("error:", error)
								print("s3key: \(newValue.key)")
								self.error = error
							}
						}
					}
				})
				.toolbar {
					ToolbarItemGroup(placement: .automatic) {
						Button(action: {
							self.updateTextContents()
						}, label: {
							Image(systemName: "arrow.clockwise")
						})
						Button(action: {
							self.addTextContent()
						}, label: {
							Image(systemName: "plus")
						})
						Spacer()
						PopoverButtonView {
							AccessTestView(session: self.session)
								.frame(width: 350, height: 400)
								.padding()
						} label: {
							Image(systemName: "ladybug")
						}
					}
					ToolbarItemGroup(placement: .navigation) {
						Button(action: {
							self.signout()
						}, label: {
							Text("Signout")
						})
					}
				}
				.navigationBarBackButtonHidden()
			}
		} detail: {
			TextContentView(session: self.session, textContent: $textContent, error: $error)
		}
		.onAppear() {
			self.updateTextContents()
		}
		.alert(Text("Error"), isPresented: .constant(self.error != nil), presenting: self.error) { error in
			Button(action: {
				self.error = nil
			}, label: {
				Text("OK")
			})
		} message: { error in
			Text("\(error)")
		}
	}
	private func updateTextContents() {
		Task {
			self.taskCount += 1
			defer { self.taskCount -= 1 }
			do {
				let items = try await ServiceManager.shared.listTextContents(session: self.session)
				print("KY:", #function, "items=", items.map { $0.key } )
				self.items = items
			} catch {
				self.error = error
			}
		}
	}
	private func addTextContent() {
		Task {
			self.taskCount += 1
			defer { self.taskCount -= 1 }
			do {
				if let object = try await ServiceManager.shared.addTextContent(session: self.session) {
					self.items.append(object)
					self.selection = object
				}
				else {
					self.error = "created content cannot be found."
				}
			} catch {
				self.error = error
			}
		}
	}
	private func deleteObject(_ object: Object) {
		Task {
			do {
				try await ServiceManager.shared.deleteObject(session: self.session, key: object.key)
				self.updateTextContents()
				self.selection = nil
			} catch {
				self.error = error
			}
		}
	}
	private func signout() {
		self.taskCount += 1
		defer { self.taskCount -= 1 }
		Task {
			do {
				try await ServiceManager.shared.signout(session: self.session)
			} catch {
				self.error = error
			}
			self.dismiss()
		}
	}
}

extension S3ClientTypes.Object: Hashable {
	public static func == (lhs: AWSS3.S3ClientTypes.Object, rhs: AWSS3.S3ClientTypes.Object) -> Bool {
		return lhs.key == rhs.key
	}
	public func hash(into hasher: inout Hasher) {
		hasher.combine(key)
	}
}
