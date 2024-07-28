//
//	String+additions.swift
//	Amber User Pool
//
//	Created by Kaz Yoshikawa on 2024/07/07.
//

import Foundation

extension CharacterSet {
	static let quoteCharctorSet = CharacterSet(charactersIn: "\"'`")
}

extension String {
	func trimmingQuoteCharactors() -> String {
		return self.trimmingCharacters(in: CharacterSet.quoteCharctorSet)
	}
}
