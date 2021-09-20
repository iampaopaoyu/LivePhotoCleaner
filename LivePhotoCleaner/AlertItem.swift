//
//  AlertItem.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 01.07.21.
//

import Foundation
import SwiftUI

struct AlertItem: Identifiable {
    var id = UUID()
    var title: String
    var message: String?
    var dismissOnly: Bool
    var dismissButton: (String, () -> Void)?
    var primaryButton: (String, () -> Void)?
    var secondaryButton: (String, () -> Void)?

    func getAlert() -> Alert {
        let titleText = Text(NSLocalizedString(title, comment: ""))
        let messageText = message != nil ? Text(NSLocalizedString(message!, comment: "")) : nil
        if dismissOnly {
            let dismiss = Alert.Button.default(Text(NSLocalizedString(dismissButton!.0, comment: "")), action: dismissButton!.1)
            return Alert(title: titleText, message: messageText, dismissButton: dismiss)
        } else {
            let primaryButton = Alert.Button.cancel(Text(NSLocalizedString(primaryButton!.0, comment: "")), action: primaryButton!.1)
            let secondaryButton = Alert.Button.destructive(Text(NSLocalizedString(secondaryButton!.0, comment: "")), action: secondaryButton!.1)
            return Alert(title: titleText, message: messageText, primaryButton: primaryButton, secondaryButton: secondaryButton)
        }
    }
}
