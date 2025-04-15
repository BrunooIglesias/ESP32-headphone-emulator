//
//  DocumentTransferButton.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/15/25.
//

import SwiftUI

struct DocumentTransferButton: View {
    @ObservedObject var viewModel: HeadphoneViewModel
    @State private var showDocumentTransfer = false

    var body: some View {
        VStack {
            Button(action: {
                showDocumentTransfer.toggle()
            }) {
                Text("Document Transfer")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()

            if viewModel.isDocumentTransferInProgress {
                ProgressView(value: viewModel.documentTransferProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding()
            }
        }
        .sheet(isPresented: $showDocumentTransfer) {
            DocumentTransferView(viewModel: viewModel)
        }
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    DocumentTransferButton(viewModel: viewModel)
}
