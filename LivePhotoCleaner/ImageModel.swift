//
//  ImageModel.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 11.01.21.
//

import UIKit
import SwiftUI
import Photos
import os.log
import Firebase

class ImageModel: NSObject, ObservableObject {

    var logger = Logger()

    var didShowiCloudAlertError = false

    @Published var approxFreedSpace = 0.0
    @Published var images = [CustomImage]()
    @Published var editedImages = [CustomImage]()
    @Published var selectedImages = [CustomImage]()
    @Published var selectedEditedItemsCount = 0

    @Published var alert: AlertItem?

    @Published var imageSum = 0
    @Published var currentImage = 0
    @Published var warningText =
"""
Die Bilder werden derzeit dupliziert.
Nachdem die Vorbereitung abgeschlossen ist kann der Vorgang nicht abgebrochen werden.
Wenn die App während dem Duplizieren beendet wird, wird der Vorgang dennoch fortgesetzt.
"""

    var fetchResults: PHFetchResult<PHAsset>?

    var imageCleanData = [String: [PHAssetResourceType : (data: Data, complete: Bool)]]()

    var imageIndexInformation = [String: (imagesIndex: Int?, editedImagesIndex: Int?, selectedImagesIndex: Int?)]()

    var assetsWithError = [PHAsset]()

    private var activeRequests = Set<PHImageRequestID>()
    private var fetchAllowed = true

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)

        fetchAllPhotos()
    }

    // MARK: - Public part

    // unmodified images
    func selectAllImages() {
        selectAllImages(of: &images)
    }

    func deselectAllImages() {
        deselectAllImages(of: &images)
    }

    // edited images
    func selectAllEditedImages() {
        selectAllImages(of: &editedImages)
        selectedEditedItemsCount = editedImages.count
    }

    func deselectAllEditedImages() {
        deselectAllImages(of: &editedImages)
        selectedEditedItemsCount = 0
    }

    // specific images
    private func deselectAllImages(of list: inout [CustomImage]) {
        let editedIDs = list.map{ $0.id }
        selectedImages = selectedImages.filter{ !editedIDs.contains($0.id) }
        for index in list.indices {
            list[index].selected = false
        }
    }

    private func selectAllImages(of list: inout [CustomImage]) {
        selectedImages.append(contentsOf: list)

        for index in list.indices {
            // bool for should be cleared
            selectedImages[index].selected = false
            // bool for is selected
            list[index].selected = true
        }
        calculateFreedSpace(selectAll: true)
    }

    // image tap actions
    func imageTapped(id: String) { // could be refactored to not always search both lists
        if let first = editedImages.first(where: { $0.id == id }) {
            if first.selected {
                selectedEditedItemsCount -= 1
            } else {
                selectedEditedItemsCount += 1
            }
        }
        image(with: id, tappedIn: &editedImages)
        image(with: id, tappedIn: &images)
        calculateFreedSpace()
    }

    private func image(with id: String, tappedIn images: inout [CustomImage]) {
        if let index = images.firstIndex(where: { $0.id == id }) {
            if images[index].selected {
                selectedImages.removeAll(where: { $0.id == id })
            } else {
                selectedImages.append(images[index])
            }

            images[index].selected.toggle()
        }
    }

    // reset
    func reset() {
        for index in images.indices {
            images[index].selected = false
        }
        for index in editedImages.indices {
            editedImages[index].selected = false
        }
        selectedEditedItemsCount = 0
        self.selectedImages.removeAll()
    }

    /// Tries to fetch all photos that are on the device and in cloud.
    /// The fetched images are added to the arrays async.
    func fetchAllPhotos() {
        self.logger.info("FetchAll started")
        fetchAllowed = true
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        allPhotosOptions.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoLive.rawValue
        )
        fetchResults = PHAsset.fetchAssets(with: allPhotosOptions)

        guard let fetchResults = self.fetchResults else {
            logger.error("Image fetch failed")
            return
        }

        var assets = [PHAsset]()
        var assetIds = Set<String>()
        fetchResults.enumerateObjects { (asset, index, stop) in
            assets.append(asset)
            assetIds.insert(asset.localIdentifier)
        }

        // we could easily calculate this if we'd use sets
        DispatchQueue.main.async {
            self.images.removeAll(where: { !assetIds.contains($0.id) })
            self.editedImages.removeAll(where: { !assetIds.contains($0.id) })
            self.selectedImages.removeAll(where: { !assetIds.contains($0.id) })
        }

        let allowIcloudImages = UserDefaults.standard.bool(forKey: Constants.includeIcloudImages)
        logger.info("Network access allowed to download photos: \(allowIcloudImages)")

        //        DispatchQueue.global(qos: .background).async { // this seems to lead to threading issues
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isNetworkAccessAllowed = allowIcloudImages
        if allowIcloudImages {
            logger.info("Adding progress handler for icloud images")
            option.progressHandler = { (progress, error, stop, additionalInfo) in
                if let error = error, self.alert != nil, !self.didShowiCloudAlertError {
                    self.didShowiCloudAlertError = true
                    self.alert = AlertItem(title: NSLocalizedString("view_photoOverview_icloudLoadAlert_title", comment: ""),
                                           message: String(format: NSLocalizedString("view_photoOverview_icloudLoadAlert_text", comment: ""), "\n", error.localizedDescription),
                                           dismissOnly: true,
                                           dismissButton: ("Ok", { self.alert = nil }))
                }

                self.logger.warning("Progress is \(progress), error occured: \(error?.localizedDescription ?? "none", privacy: .public)\n\(additionalInfo?.description ?? "no additional info", privacy: .public)")
            }
        }

        for index in 0..<assets.count {
            if !fetchAllowed { break }
            self.logger.log("\(assets[index].localIdentifier)")

            let requestId = manager.requestImage(for: assets[index],
                                    targetSize: CGSize(width: 500, height: 500),
                                    contentMode: .aspectFit,
                                    options: option,
                                    resultHandler: { (result, info) -> Void in
                if let inf = info, let key = inf[PHImageResultIsInCloudKey] as? String {
                    self.logger.info("Cloud image key: \(key)")

                    if !self.images.contains(where: { $0.id == assets[index].localIdentifier }) {
                        // maybe replace this image with the placeholder only in case it is not yet in any list
                        // it seems as if the placeholder is in general present, but the image is not loaded correctly. so we add this image only if there is none yet.
                        // this might result in no high-res image, so another rework might be needed
                        self.createAndAddImage(assets[index], UIImage(systemName: "photo") ?? UIImage())
                    }
                    if key == "0" && !allowIcloudImages {
                        self.logger.info("Cloud image key is 0, will return from function as cloud image download is not allowed.")
                        self.alert = AlertItem(title: "view_photoOverview_enableIcloudLoadAlert_title",
                                  message: "view_photoOverview_enableIcloudLoadAlert_text",
                                  dismissOnly: false,
                                  primaryButton: ("view_photoOverview_enableIcloudLoadAlert_abort", { self.alert = nil }),
                                  secondaryButton: ("view_photoOverview_enableIcloudLoadAlert_load", {
                                    self.fetchAllowed = false
                                    for id in self.activeRequests {
                                        manager.cancelImageRequest(id)
                                        self.images.removeAll()
                                        self.editedImages.removeAll()
                                        self.selectedImages.removeAll()
                                        UserDefaults.standard.set(true, forKey: Constants.includeIcloudImages)
                                        self.fetchAllPhotos()
                                    }
                                  }))
                        return
                    }
                }

                if let res = result {
                    self.createAndAddImage(assets[index], res)
                    if let degraded = info?["PHImageResultIsDegradedKey"] as? NSNumber, let id = info?["PHImageResultRequestIDKey"] as? NSNumber {
                        if !degraded.boolValue {
                            self.logger.info("removing id \(id)")
                        }
                    }
                }
            })
            logger.info("adding id \(requestId)")
            activeRequests.insert(requestId)
        }
        //        }
        self.logger.info("FetchAll finished")
    }

    func deleteApproved() {
        self.logger.log("Delete approved")
        imageCleanData.removeAll()
        assetsWithError.removeAll()
        var assetsToDelete: [PHAsset] = [PHAsset]()
        fetchResults?.enumerateObjects { (asset, index, stop) in
            if self.selectedImages.contains(where: { $0.id == asset.localIdentifier }) {
                assetsToDelete.append(asset)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if UserDefaults.standard.bool(forKey: Constants.moveToAlbum) {
                self.createLPCAlbumIfNotPresent()
            }

            self.createStillPhotos(for: assetsToDelete)
        }
    }

    func deleteSelectedLivePhotos() {
        if selectedEditedItemsCount == 0 {
            deleteApproved()
        } else {
            alert = AlertItem(title: "view_selectedPhotoOverview_alert_warning_title",
                              message: String(format: "view_selectedPhotoOverview_alert_warning_message", selectedEditedItemsCount),
                              dismissOnly: false,
                              primaryButton: ("view_selectedPhotoOverview_alert_cancel_button", action: {}),
                              secondaryButton: ("view_selectedPhotoOverview_alert_continue_button", action: deleteApproved))
        }
    }

    // MARK: - Private helper methods

    fileprivate func createStillPhotos(for assetsToDelete: [PHAsset]) {
        // neues photo anlegen ohne video komponente

        for asset in assetsToDelete {
            self.imageCleanData[asset.localIdentifier] = [PHAssetResourceType : (data: Data, complete: Bool)]() // create empty dicts for asset

            let resource = PHAssetResource.assetResources(for: asset) // get photo component
                                                                      //            self.logger.log("Current resource:\n\(resource)")

            for resourcePart in resource {
                self.logger.log("Current resource part \n\(resourcePart)")
                if !self.validTypesOf(resourcePart) {
                    continue
                }
                self.imageCleanData[asset.localIdentifier]?[resourcePart.type] = (Data(), false)
            }
        }

        assetsToDelete.forEach { asset in
            let resource = PHAssetResource.assetResources(for: asset) // get photo component

            for resourcePart in resource {
                if !self.validTypesOf(resourcePart) {
                    continue
                }
                self.logger.log("Requesting resource data")

                //
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = UserDefaults.standard.bool(forKey: Constants.includeIcloudImages)
                PHAssetResourceManager.default().requestData(for: resourcePart, options: options,
                                                                dataReceivedHandler: { data in
                    self.imageCleanData[asset.localIdentifier]?[resourcePart.type]?.data.append(data)
                },
                                                                completionHandler: { error in
                    if let err = error {
                        self.logger.error("\(err.localizedDescription)")
                    } else {
                        self.logger.log("Received complete data of type \(resourcePart.type.rawValue).")
                        self.imageCleanData[asset.localIdentifier]?[resourcePart.type]?.complete = true
                        self.createNewAssets(for: assetsToDelete)
                    }
                })
            }
        }
    }

    fileprivate func createNewAssets(for assets: [PHAsset]) {

        logger.info("Checking data for assets (completeness)")
        for (_, array) in imageCleanData {
            for tuple in array {
                if !tuple.value.complete {
                    logger.info("Not all data sets are complete yet, waiting for next request.")
                    return
                }
            }
        }
        logger.info("Data complete, starting to create new assets.")

        var albumListForAssets = [String: [PHAssetCollection]]()

        logger.info("Retrieving album information for assets")
        for asset in assets {
            albumListForAssets[asset.localIdentifier] = getAlbumList(for: asset)
        }

        logger.info("Creating change request")
        DispatchQueue.main.async {
            self.imageSum = assets.count
            self.currentImage = 0
        }

        logger.info("Asset ResourceType combination is supported: \(PHAssetCreationRequest.supportsAssetResourceTypes([1]))") // 1: photo, 7: adjustment data, 5: full size image

        PHPhotoLibrary.shared().performChanges({
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true

            for asset in assets {
                DispatchQueue.main.async {
                    self.currentImage += 1
                }

                if let imageData = self.imageCleanData[asset.localIdentifier] {
                    self.logger.log("Creating new Asset request for asset \(asset.localIdentifier)")
                    let request = PHAssetCreationRequest.forAsset()

                    self.logger.log("Adding data for type: \(PHAssetResourceType.photo.rawValue) [PHAssetResourceType]")
                    request.addResource(with: .photo, data: imageData[.photo]?.data ?? Data(), options: options)

                    //                    let createdAssetPlaceholder = request.placeholderForCreatedAsset!

                    //                    for tuple in imageData {
                    //                        if tuple.key == .adjustmentData {
                    //                            self.logger.log("Adding adjustment data to content editing output.")
                    //                            let editingOutput = PHContentEditingOutput(placeholderForCreatedAsset: createdAssetPlaceholder)
                    //                            editingOutput.adjustmentData = PHAdjustmentData.init(formatIdentifier: "app.a", formatVersion: "1.0", data: tuple.value.data)
                    //                            request.contentEditingOutput = editingOutput
                    //                        } else if tuple.key == .fullSizePhoto {
                    //                            self.logger.log("Adding full size photo to request.")
                    //                            request.addResource(with: .fullSizePhoto, data: tuple.value.data, options: options)
                    //                        }
                    //                    }

                    self.logger.info("Adding new asset album(s) if any")
                    for collection in albumListForAssets[asset.localIdentifier] ?? [PHAssetCollection]() {
                        let addAssetRequest = PHAssetCollectionChangeRequest(for: collection)
                        addAssetRequest?.addAssets([request.placeholderForCreatedAsset!] as NSArray)
                    }

                    if UserDefaults.standard.bool(forKey: Constants.moveToAlbum) {
                        self.logger.info("Adding new asset to lpc album")
                        if let album = self.getLPCAlbum() {
                            let addAssetRequest = PHAssetCollectionChangeRequest(for: album)
                            addAssetRequest?.addAssets([request.placeholderForCreatedAsset!] as NSArray)
                        }
                    }
                } else {
                    self.logger.warning("No image data for current asset \(asset.localIdentifier)")
                }

            }
            if UserDefaults.standard.bool(forKey: Constants.deleteLivePhotos) {
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }
        }) { (succeeded, error) in
            if succeeded {
                self.logger.info("Successfully added assets.")
                if !UserDefaults.standard.bool(forKey: Constants.deleteLivePhotos) {
                    DispatchQueue.main.async {
                        self.alert = AlertItem(title: "view_selectedPhotoOverview_alert_success_title",
                                               message: "view_selectedPhotoOverview_alert_success_message",
                                               dismissOnly: true,
                                               dismissButton: ("view_selectedPhotoOverview_alert_success_button", action: self.reset))
                    }
                } else {
                    DispatchQueue.main.async {
                        self.reset()
                    }
                }
            } else if let err = error {
                self.logger.log("\(error?.localizedDescription ?? "")")
                DispatchQueue.main.async {
                    self.alert = AlertItem(title: "view_selectedPhotoOverview_alert_error_title",
                                           message: NSLocalizedString("view_selectedPhotoOverview_alert_error_message", comment: "") +  "\(err.localizedDescription)",
                                           dismissOnly: true,
                                           dismissButton: ("view_selectedPhotoOverview_alert_error_dismissButton", action: self.reset))
                }
            }
        }
    }


    fileprivate func createAndAddImage(_ asset: PHAsset, _ res: UIImage) {
        DispatchQueue.global(qos: .background).async {
            //        self.logger.debug("adding asset \(asset.localIdentifier)")
            let isEdited = PHAssetResource.assetResources(for: asset).contains(where: { $0.type == .adjustmentData } )

            if let tupleForImage = self.imageIndexInformation[asset.localIdentifier] {
                if let editedIndex = tupleForImage.editedImagesIndex {
                    DispatchQueue.main.async {
                        Crashlytics.crashlytics().log("updating edited image")
                        self.editedImages[editedIndex].image = res
                    }
                }
                if let imagesIndex = tupleForImage.imagesIndex {
                    DispatchQueue.main.async {
                        Crashlytics.crashlytics().log("updating normal image")
                        self.images[imagesIndex].image = res
                    }
                }
                if let selectedImagesIndex = tupleForImage.selectedImagesIndex {
                    DispatchQueue.main.async {
                        Crashlytics.crashlytics().log("updating selected image")
                        self.selectedImages[selectedImagesIndex].image = res
                    }
                }
            } else {
                let image = CustomImage(id: asset.localIdentifier, image: res)
                if isEdited {
                    DispatchQueue.main.async {
                        Crashlytics.crashlytics().log("adding new edited image")
                        self.editedImages.append(image)
                        self.imageIndexInformation[asset.localIdentifier] = (nil, self.editedImages.count - 1, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        Crashlytics.crashlytics().log("adding new normal image")
                        self.images.append(image)
                        self.imageIndexInformation[asset.localIdentifier] = (self.images.count - 1, nil, nil)
                    }
                }
            }
            //        self.logger.debug("adding asset \(asset.localIdentifier) finished at")
        }
    }

    fileprivate func validTypesOf(_ resourcePart: PHAssetResource) -> Bool{
        if resourcePart.type != .photo && resourcePart.type != .fullSizePhoto && resourcePart.type != .adjustmentData {
            logger.log("Type not matching, continue.")
            return false
        }
        return true
    }
}

// MARK: - Calculations

extension ImageModel {
    private func calculateFreedSpace(selectAll: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async {
            var fileSize = 0.0

            self.fetchResults?.enumerateObjects { (asset, index, stop) in
                if selectAll || self.selectedImages.contains(where: { $0.id == asset.localIdentifier }) {
                    PHAssetResource.assetResources(for: asset).forEach { resouce in
                        if resouce.type == .pairedVideo || resouce.type == .fullSizePairedVideo || resouce.type == .adjustmentBasePairedVideo {
                            fileSize += resouce.value(forKey: "fileSize") as? Double ?? 0
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.approxFreedSpace = (fileSize/(1024.0*1024.0)).roundToDecimal(2)
                self.logger.info("\(self.approxFreedSpace)")
            }
        }
    }
}

// MARK: - Album information
extension ImageModel {

    fileprivate func createLPCAlbumIfNotPresent() {
        var lpcAlbum: PHAssetCollection? = nil
        let userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)

        for index in 0..<userCollections.count {
            if userCollections.object(at: index).localizedTitle == Constants.lpcAlbumName {
                lpcAlbum = userCollections.object(at: index) as? PHAssetCollection
            }
        }

        // If it does not exist....
        if lpcAlbum == nil {
            do {
                try PHPhotoLibrary.shared().performChangesAndWait ({
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: Constants.lpcAlbumName)
                })
            } catch {
                self.logger.critical("Unable to create new album!")
            }
        }
    }

    fileprivate func getAlbumList(for asset: PHAsset) -> [PHAssetCollection] {
        //        let userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil) // fetching user collections


        var collections = Set<PHAssetCollection>()
        var fetchedCollection = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)

        for index in 0..<fetchedCollection.count {
            collections.insert(fetchedCollection.object(at: index))
        }

        fetchedCollection = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .smartAlbum, options: nil)
        for index in 0..<fetchedCollection.count {
            collections.insert(fetchedCollection.object(at: index))
        }

        return Array(collections)
    }

    fileprivate func getLPCAlbum() -> PHAssetCollection? {
        let userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)

        for index in 0..<userCollections.count {
            if userCollections.object(at: index).localizedTitle == Constants.lpcAlbumName {
                return userCollections.object(at: index) as? PHAssetCollection
            }
        }

        return nil
    }
}

// MARK: - Delegate Methods

extension ImageModel: PHPhotoLibraryChangeObserver {

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard self.fetchResults != nil else {
            logger.info("No images fetched yet")
            return
        }

        let fetchResultChangeDetails = changeInstance.changeDetails(for: self.fetchResults!)
        guard fetchResultChangeDetails != nil else {
            logger.info("No change in fetchResultChangeDetails")
            return;
        }
        logger.info("Contains changes - updating")

        if !(fetchResultChangeDetails?.insertedObjects.isEmpty ?? true) {
            // add

            let allowCloud = UserDefaults.standard.bool(forKey: Constants.includeIcloudImages)
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            option.isNetworkAccessAllowed = allowCloud

            for asset in fetchResultChangeDetails!.insertedObjects {
                manager.requestImage(for: asset, targetSize: CGSize(width: 500, height: 500), contentMode: .aspectFit, options: option, resultHandler: { (result, info) -> Void in
                    if let inf = info, let key = inf[PHImageResultIsInCloudKey] as? String {
                        self.logger.info("Cloud image key: \(key)")
                        //                        self.createAndAddImage(asset, UIImage(systemName: "photo") ?? UIImage())
                        if key == "0" && !allowCloud {
                            self.logger.info("Cloud image key is 0, will return from function as cloud image download is not allowed.")
                            return
                        }
                    }

                    if let res = result {
                        self.createAndAddImage(asset, res)
                    }
                })
            }
        }

        //        if !(fetchResultChangeDetails?.changedObjects.isEmpty ?? true) {
        //            // change
        //        }

        if !(fetchResultChangeDetails?.removedObjects.isEmpty ?? true) {
            // deleted
            for asset in fetchResultChangeDetails!.removedObjects {
                DispatchQueue.main.async {
                    self.images.removeAll(where: { asset.localIdentifier == $0.id })
                    self.selectedImages.removeAll(where: { asset.localIdentifier == $0.id })
                    self.editedImages.removeAll(where: { asset.localIdentifier == $0.id })
                    self.imageIndexInformation.removeValue(forKey: asset.localIdentifier)
                }
            }
        }

        let fetchAfterChanges = fetchResultChangeDetails?.fetchResultAfterChanges
        self.fetchResults = fetchAfterChanges
        logger.info("Contains changes - updating finished")
    }
}
