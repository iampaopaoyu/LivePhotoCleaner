//
//  SettingsModel.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 15.01.21.
//

import Photos
import os.log
import SwiftUI

class SettingsModel: ObservableObject {

    let logger = Logger.init()

    @AppStorage(Constants.includeIcloudImages) var includeIcloudPhotos = false
    @AppStorage(Constants.deleteLivePhotos) var deleteOriginalPhotos = false
    @AppStorage(Constants.moveToAlbum) var moveToAlbum = false

    public var accessLevelDescription: String {
        let currentLevel: String

        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined:
            currentLevel = "view_appSettings_accessLevelDescription_notDetermined"
        case .restricted:
            currentLevel = "view_appSettings_accessLevelDescription_restricted"
        case .denied:
            currentLevel = "view_appSettings_accessLevelDescription_denied"
        case .authorized:
            currentLevel = "view_appSettings_accessLevelDescription_authorized"
        case .limited:
            currentLevel = "view_appSettings_accessLevelDescription_limited"
        @unknown default:
            currentLevel = "view_appSettings_accessLevelDescription_unknown"
        }

        return currentLevel
    }
}
