//
//  SelectedImagesOverview.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 15.01.21.
//

import SwiftUI

struct SelectedImagesOverview: View {
    @ObservedObject var model: ImageModel

    @State private var isCleaningHidden = true

    private var columns = [GridItem(.adaptive(minimum: Constants.imageWidth), spacing: 3)]

    init(model: ImageModel) {
        self.model = model
    }

    fileprivate func createSectionHeaderForFreedSpace() -> some View {
        var text: Text
        if UserDefaults.standard.bool(forKey: Constants.deleteLivePhotos) {
            text = Text(String(format: NSLocalizedString("view_selectedPhotoOverview_freedSpace_active", comment: ""),
                               String(format: "%.2f", model.approxFreedSpace)))
        } else {
            text = Text("view_selectedPhotoOverview_freedSpace_inactive")
        }
        return HStack {
            text
            Spacer()
        }
    }

    var body: some View {
        VStack {
            ZStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 3, pinnedViews: .sectionFooters) {
                        Section(header: createSectionHeaderForFreedSpace()) {
                            ForEach(model.selectedImages, id: \.self.id) { image in
                                getImageView(image)
                                    //.gesture(magnification)
                            }
                        }
                    }.padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top)

                }.navigationTitle("view_selectedPhotoOverview_navigation_title")
//                Color.white.opacity(0.8).isHidden(isCleaningHidden)
//                VStack {
//                    Text("Vorbereitung....")
//                    Text("Bild \(model.currentImage)/\(model.imageSum) wird vorbereitet")
//                    Text(model.warningText)
//                }.isHidden(isCleaningHidden)
            }
            Button(
                action: {
                    withAnimation {
                        isCleaningHidden = false
                    }
                    model.deleteSelectedLivePhotos()
                },
                label: {
                    HStack {
                        ProgressView().progressViewStyle(CircularProgressViewStyle()).hidden()
                        Text("view_selectedPhotoOverview_startButton").padding(.horizontal)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .isHidden(isCleaningHidden)
                    }
                })
            .buttonStyle(FilledButton())
        }.alert(item: $model.alert) { alertItem in
            alertItem.getAlert()
        }
    }

    fileprivate func getImageView(_ image: CustomImage) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: image.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: Constants.minimumImageWidth, idealWidth: Constants.imageWidth, maxWidth: .infinity, minHeight: Constants.minimumImageHeight, idealHeight: Constants.imageHeight, maxHeight: .infinity, alignment: .center)
                .clipped()
            Color.white.opacity(image.overlayTransparency)
            Image(systemName: "minus.circle.fill")
                .padding(2)
                .foregroundColor(Color.red)
                .background(Circle().foregroundColor(Color.white).padding(2))
        }.onTapGesture {
            withAnimation {
                model.imageTapped(id: image.id)
            }
        }
    }
}

struct SelectedImagesOverview_Previews: PreviewProvider {
    static var previews: some View {
        //SelectedImagesOverview()
        EmptyView()
    }
}
