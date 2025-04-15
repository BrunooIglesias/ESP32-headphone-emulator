//
//  DocumentTransferView.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/15/25.
//

import SwiftUI

struct DocumentTransferView: View {
    @ObservedObject var viewModel: HeadphoneViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isDocumentTransferInProgress {
                    ProgressView(value: viewModel.documentTransferProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding()
                    
                    Text("Transferring document... \(Int(viewModel.documentTransferProgress * 100))%")
                        .foregroundColor(.gray)
                } else {
                    Button(action: {
                        viewModel.startDocumentTransfer()
                    }) {
                        Text("Start Document Transfer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        viewModel.endDocumentTransfer()
                    }) {
                        Text("End Document Transfer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("Document Transfer")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return DocumentTransferView(viewModel: viewModel)
}
