//
//	PopoverButtonView.swift
//
//	Created by Kaz Yoshikawa on 2024/06/12.
//

import SwiftUI

/**
 `PopoverButtonView` is a reusable SwiftUI view that displays a button, which presents a popover when tapped.
 
	The view is highly customizable, allowing you to specify any type of view for both the button's label and the popover's content.
 
	Usage:
		PopoverButtonView(label: {
			Text("Show Popover")
		}, popoverContent: {
			Text("This is the popover content")
				.padding()
		})
		.padding()

	- Parameters:
		T: The type of view to be used as the button's label.
 		U: The type of view to be used as the popover's content.
 
 	- Note:
		- The `isPresentingPopover` state variable controls the presentation of the popover.
		- The `label` and `popoverContent` closures provide the views for the button's label and popover content, respectively.
 */


struct PopoverButtonView<T: View, U: View>: View {
	@State private var isPresentingPopover = ObservableValueObject(value: false)
	let content: () -> U
	let label: () -> T
	
	init(content: @escaping () -> U, label: @escaping () -> T) {
		self.label = label
		self.content = content
	}
	
	var body: some View {
		Button(action: { self.isPresentingPopover.value.toggle() }) {
			self.label()
		}
		.popover(isPresented: isPresentingPopover.binding) {
			self.content()
				.environment(isPresentingPopover)
		}
	}
}
