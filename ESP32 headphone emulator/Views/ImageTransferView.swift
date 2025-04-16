import SwiftUI
import PhotosUI

struct ImageTransferView: View {
    @ObservedObject var viewModel: HeadphoneViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let imageData = selectedImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .foregroundColor(.gray)
                }
                
                PhotosPicker(selection: $selectedItem,
                           matching: .images) {
                    Label("Select Image", systemImage: "photo.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                if selectedImageData != nil {
                    Button(action: {
                        if let imageData = selectedImageData {
                            viewModel.sendImage(imageData)
                        }
                        dismiss()
                    }) {
                        Label("Send to ESP32", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                
                if viewModel.isImageTransferInProgress {
                    VStack {
                        ProgressView(value: viewModel.imageTransferProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        Text("\(Int(viewModel.imageTransferProgress * 100))%")
                            .foregroundColor(.white)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Image Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ImageTransferView(viewModel: viewModel)
} 
