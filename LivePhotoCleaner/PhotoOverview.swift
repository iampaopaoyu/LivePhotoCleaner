//
//  ContentView.swift
//  LivePhotosCleanUp
//
//  Created by Denise Fritsch on 29.09.20.
//

import SwiftUI
import PhotosUI

struct PhotoOverview: View {

    private enum ButtonLabels: String {
        case imageSelection = "view_photoOverview_checkButton"
    }

    private var buttonTextPadding: CGFloat = 4

    // model
    @StateObject var imageModel = ImageModel()

    // App state
    @State private var presentSettingsSheet: Bool = false
    @State private var numberOfColumns = 3 // ios: 1,3,5; ipadOS: 1,3,7 ? magnification gesture?
    @State private var buttonText = ButtonLabels.imageSelection.rawValue

    private var columns: [GridItem]

    init() {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            columns = Array.init(repeating: GridItem(.adaptive(minimum: Constants.imageWidth), spacing: 3), count: 3)
        case .pad, .mac:
            columns = Array.init(repeating: GridItem(.adaptive(minimum: Constants.imageWidth), spacing: 3), count: 7)
        case .carPlay, .tv, .unspecified:
            fallthrough
        @unknown default:
            columns = Array.init(repeating: GridItem(.adaptive(minimum: Constants.imageWidth), spacing: 3), count: 3)
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 3, pinnedViews: .sectionHeaders) {
                        if imageModel.images.count == 0 && imageModel.editedImages.count == 0 {
                            Text("view_photoOverview_noLivePhotos")
                        }
                        if imageModel.images.count > 0 {
                            Section(header: getSectionHeader(title: "view_photoOverview_livePhotosNormal",
                                                             selectAllAction: imageModel.selectAllImages,
                                                             deselectAllAction: imageModel.deselectAllImages).padding(.top)) {
                                ForEach(imageModel.images) { image in
                                    getImageView(image, edited: false)
                                }
                            }
                        }
                        if imageModel.editedImages.count > 0 {
                            Section(header:
                                        VStack {
                                            getSectionHeader(title: "view_photoOverview_livePhotosEdited",
                                                             selectAllAction: imageModel.selectAllEditedImages,
                                                             deselectAllAction: imageModel.deselectAllEditedImages).padding(.top)
                                            Text("view_photoOverview_editLostWarning")
                                        }) {
                                ForEach(imageModel.editedImages) { image in
                                    getImageView(image, edited: true)
                                }
                            }
                        }
                    }.padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top)
                }
                NavigationLink(destination: SelectedImagesOverview(model: imageModel)) {
                    Text(NSLocalizedString(buttonText, comment: ""))
                }
                .padding()
                .foregroundColor(Color.white)
                .background(LinearGradient(gradient: Gradient(colors: [Color.accentColor .opacity(0.8), Color.accentColor.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottom))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 20)
                .isHidden(imageModel.selectedImages.isEmpty, remove: true)
                .padding(.bottom)
            }
            .onAppear {
                imageModel.didShowiCloudAlertError = false
            }
            .navigationBarItems(trailing: getNavigationBarTrailing())
            .navigationBarTitle(Text("view_photoOverview_navigation_title"))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    fileprivate func getImageView(_ image: CustomImage, edited: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: image.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: Constants.minimumImageWidth, idealWidth: Constants.imageWidth, maxWidth: .infinity, minHeight: Constants.minimumImageHeight, idealHeight: Constants.imageHeight, maxHeight: .infinity, alignment: .center)
                .clipped()
            Color.white.opacity(image.overlayTransparency)
            if image.selected {
                Image(systemName: "checkmark.circle.fill")
                    .padding(2)
                    .foregroundColor(Color.accentColor)
                    .background(Circle().foregroundColor(Color.white).padding(2))
            }
        }.onTapGesture {
            withAnimation {
                imageModel.imageTapped(id: image.id)
            }
        }
    }

    fileprivate func getSectionHeader(title: String, selectAllAction: @escaping () -> Void, deselectAllAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString(title, comment: ""))
                .padding(buttonTextPadding)
                .background(Capsule().foregroundColor(Color(UIColor.systemBackground)).opacity(0.5))
            HStack {
                Spacer()
                Button("view_photoOverview_selectAll", action: selectAllAction)
                    .padding(buttonTextPadding)
                    .background(Capsule().foregroundColor(Color(UIColor.systemGray5)))
                Button("view_photoOverview_deselectAll", action: deselectAllAction)
                    .padding(buttonTextPadding)
                    .background(Capsule().foregroundColor(Color(UIColor.systemGray5)))
            }
        }
    }

    fileprivate func getNavigationBarTrailing() -> some View {
        Button(action: { presentSettingsSheet.toggle() },
               label: { Image(systemName: "gear")})
            .sheet(isPresented: $presentSettingsSheet, content: {
                AppSettingsView(isSheetVisible: $presentSettingsSheet)
            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoOverview()
            .preferredColorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPhone 12"))
            .previewDisplayName("iPhone 12 dark")
        PhotoOverview()
            .preferredColorScheme(.light)
            .previewDevice(PreviewDevice(rawValue: "iPhone 12"))
            .previewDisplayName("iPhone 12 light")
    }
}

