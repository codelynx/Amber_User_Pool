//
//	ObservableValueObject.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/06/17.
//

import Foundation
import SwiftUI

@Observable
class ObservableValueObject<T> {
	var value: T
	init(value: T) {
		self.value = value
	}
	var binding: Binding<T> {
		Binding(
			get: { self.value },
			set: { self.value = $0 }
		)
	}
}
