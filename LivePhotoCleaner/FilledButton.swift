//
//  ButtonStyle.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 12.01.21.
//

import SwiftUI


struct FilledButton: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        return AnyView(configuration.label
            .padding()
            .foregroundColor(Color.white)
            .background(LinearGradient(gradient: Gradient(colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottom))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 20))
    }
}
