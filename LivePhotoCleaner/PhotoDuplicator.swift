//
//  PhotoDuplicator.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 15.10.21.
//

import Foundation
import Photos
import os.log
import SwiftUI

/// Sepecific class to duplicate a given set of PHPhotos
class PhotoDuplicator {

    private var logger = Logger(subsystem: "PhotoDuplicator", category: "photo duplication")

    private let duplicationBlockSize = 25
    var ignoreCloudError = false

    private var assetsFoDuplication: [PHAsset]
    private var duplicatedAssets: [PHAsset]
    private var imageCleanData = [String: [PHAssetResourceType : (data: Data, complete: Bool)]]()

    private var completionHandler: () -> Void
    private var progressHandler: ([String]) -> Void
    private var alertHandler: (PhotoDuplicatorAlertTypes, PHPhotosError?) -> Void

    init() {
        logger.debug("PhotoDuplicator init called.")
        assetsFoDuplication = [PHAsset]()
        duplicatedAssets =  [PHAsset]()

        self.completionHandler = {}
        self.progressHandler = {_ in }
        self.alertHandler = {_, _ in }
    }

    func setCallbackHandlers(completionHandler: @escaping () -> Void,
                             progressHandler: @escaping ([String]) -> Void,
                             alerthandler: @escaping (PhotoDuplicatorAlertTypes, PHPhotosError?) -> Void) {

        self.completionHandler = completionHandler
        self.progressHandler = progressHandler
        self.alertHandler = alerthandler
    }


    ///Init - expects a list of PHAssets for duplication
    ///
    /// - parameter assets: The assets that should be duplicated
    func setAssets(assets: [PHAsset]) {
        imageCleanData.removeAll()
        duplicatedAssets = [PHAsset]()

        assetsFoDuplication = assets.reversed()
    }

    /**
     Starts the duplication of the assets given during intialization.
     Will call the completion handler as soon as all images are finished
     and the error handler in case of failure.
     */
    public func startDuplication() {
        logger.debug("startDuplication called")
        // prepare
        imageCleanData.removeAll()

        let block: [PHAsset]
        // get block
        if !(duplicationBlockSize < 1) {
            block = assetsFoDuplication.suffix(duplicationBlockSize)
            assetsFoDuplication = assetsFoDuplication.dropLast(block.count)
        } else {
            block = assetsFoDuplication
        }

        // prepare clean data - load missing asset parts
        prepareImageCleanData(for: block)

        // create new images
        loadAssetData(for: block, completion: createNewAssets(for:))
    }

    // MARK: Prepare and load
    fileprivate func prepareImageCleanData(for assetsToDelete: [PHAsset]) {
        // get image clean data - load asset parts / components
        imageCleanData.removeAll()
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
    }

    fileprivate func loadAssetData(for assetsToDelete: [PHAsset], completion: @escaping ([PHAsset]) -> Void) {
        var shouldContinue = true
        for index in 0..<assetsToDelete.count {
            if !shouldContinue { break }
            let asset = assetsToDelete[index]
            let resources = PHAssetResource.assetResources(for: asset) // get photo component

            for resourcePart in resources {
                if !self.validTypesOf(resourcePart) {
                    continue
                }
                self.logger.log("Requesting resource data")

                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = UserDefaults.standard.bool(forKey: Constants.includeIcloudImages)
                PHAssetResourceManager.default().requestData(for: resourcePart,
                                                                options: options,
                                                                dataReceivedHandler: { data in
                    self.imageCleanData[asset.localIdentifier]?[resourcePart.type]?.data.append(data)
                },
                                                                completionHandler: { error in
                    if let err = error as? PHPhotosError {
                        if err.code == PHPhotosError.Code.networkAccessRequired && !self.ignoreCloudError {
                            // FIXME enable
                            self.logger.error("No network access granted but needed.")
                            shouldContinue = false
                            self.alertHandler(.unableToLoadCloudAssetData, nil)
                        }
                        self.logger.error("Recieved error on data request \(err.localizedDescription)")
                    } else {
                        self.logger.log("Received complete data of type \(resourcePart.type.rawValue).")
                        self.imageCleanData[asset.localIdentifier]?[resourcePart.type]?.complete = true
                        if self.allAssetsComplete() {
                            completion(assetsToDelete)
                        }
                    }
                })
            }
        }
    }

    fileprivate func allAssetsComplete() -> Bool {
        logger.info("Checking data for assets (completeness)")
        for (_, array) in imageCleanData {
            for tuple in array {
                if !tuple.value.complete {
                    logger.info("Not all data sets are complete yet, waiting for next request.")
                    return false
                }
            }
        }
        logger.info("Data complete.")
        return true
    }

    // MARK: Create new / continue
    fileprivate func createNewAssets(for assets: [PHAsset]) {
        var albumListForAssets = [String: [PHAssetCollection]]()

        logger.info("Retrieving album information for assets")
        for asset in assets {
            albumListForAssets[asset.localIdentifier] = getAlbumList(for: asset)
        }

        logger.info("Creating change request")
        logger.info("Asset ResourceType combination is supported: \(PHAssetCreationRequest.supportsAssetResourceTypes([1]))") // 1: photo, 7: adjustment data, 5: full size image

        let lpcAlbum = self.getLPCAlbum()

        PHPhotoLibrary.shared().performChanges({
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true

            for asset in assets {
                if let imageData = self.imageCleanData[asset.localIdentifier] {
                    self.logger.log("Creating new Asset request for asset \(asset.localIdentifier)")
                    let request = PHAssetCreationRequest.forAsset()

                    self.logger.log("Adding data for type: \(PHAssetResourceType.photo.rawValue) [PHAssetResourceType]")
                    request.addResource(with: .photo, data: imageData[.photo]?.data ?? Data(), options: options)

// Edited asset content - add later on
                    let createdAssetPlaceholder = request.placeholderForCreatedAsset!
                    for tuple in imageData {
                        if tuple.key == .adjustmentData {
                            self.logger.log("Adding adjustment data to content editing output.")
                            let editingOutput = PHContentEditingOutput(placeholderForCreatedAsset: createdAssetPlaceholder)
                            editingOutput.adjustmentData = PHAdjustmentData.init(formatIdentifier: "app.a", formatVersion: "1.0", data: tuple.value.data)
                            request.contentEditingOutput = editingOutput
                        } else if tuple.key == .fullSizePhoto {
                            self.logger.log("Adding full size photo to request.")
                            request.addResource(with: .fullSizePhoto, data: tuple.value.data, options: options)
                        }
                    }

                    self.logger.info("Adding new asset album(s) if any")
                    for collection in albumListForAssets[asset.localIdentifier] ?? [PHAssetCollection]() {
                        let addAssetRequest = PHAssetCollectionChangeRequest(for: collection)
                        addAssetRequest?.addAssets([request.placeholderForCreatedAsset!] as NSArray)
                    }

                    if UserDefaults.standard.bool(forKey: Constants.moveToAlbum) {
                        self.logger.info("Adding new asset to lpc album")
                        if let album = lpcAlbum {
                            let addAssetRequest = PHAssetCollectionChangeRequest(for: album)
                            addAssetRequest?.addAssets([request.placeholderForCreatedAsset!] as NSArray)
                        }
                    }
                } else {
                    self.logger.warning("No image data for current asset \(asset.localIdentifier)")
                }
            }
        }) { (succeeded, error) in
            if succeeded {
                self.logger.debug("Moving asset succeeded.")
                self.duplicatedAssets.append(contentsOf: assets)
                self.didDuplicate(block: assets)
            } else if let err = error as? PHPhotosError {
                self.logger.debug("\(error?.localizedDescription ?? "")")
                self.logger.debug("\(self.duplicatedAssets.count)")
                self.alertHandler(.assetCreationError, err)
            }
        }
    }

    fileprivate func didDuplicate(block: [PHAsset]) {
        self.progressHandler(block.map({ asset in return asset.localIdentifier }))
        if assetsFoDuplication.isEmpty {
            self.logger.info("Successfully added assets deleting if needed.")
            // next steps: delete assets if needed
            // add deleted assets to list of already deleted assets
            // remove assets from visible / selection screen
            if UserDefaults.standard.bool(forKey: Constants.deleteLivePhotos) {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(self.duplicatedAssets as NSFastEnumeration)
                }) { (succeeded, error) in
                    if succeeded {
                        self.logger.debug("did finish delete")
                        self.completionHandler()
                    } else if let err = error as? PHPhotosError {
                        self.logger.log("\(error?.localizedDescription ?? "")")
                        self.alertHandler(.assetDeletionError, err)
                    }
                    self.imageCleanData.removeAll()
                }
            } else {
                self.alertHandler(.didFinishDuplicateWithoutDelete, nil)
            }
        } else {
            startDuplication()
        }
    }
}

// MARK: - Helper methods

extension PhotoDuplicator {

    // MARK: Album operations
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

    // MARK: PHAsset type checks
    fileprivate func validTypesOf(_ resourcePart: PHAssetResource) -> Bool{
        if resourcePart.type != .photo && resourcePart.type != .fullSizePhoto && resourcePart.type != .adjustmentData {
            logger.log("Type not matching, continue.")
            return false
        }
        return true
    }

}
