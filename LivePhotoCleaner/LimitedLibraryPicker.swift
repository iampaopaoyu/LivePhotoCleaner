//
//  LimitedLibraryPicker.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 14.01.21.
//

import SwiftUI
import PhotosUI
import Photos

struct LimitedLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()

        DispatchQueue.main.async {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
            context.coordinator.trackCompletion(in: controller)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject {
        private var isPresented: Binding<Bool>
        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func trackCompletion(in controller: UIViewController) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak controller] in
                if controller?.presentedViewController == nil {
                    self?.isPresented.wrappedValue = false
                } else if let controller = controller {
                    self?.trackCompletion(in: controller)
                }
            }
        }
    }
}
