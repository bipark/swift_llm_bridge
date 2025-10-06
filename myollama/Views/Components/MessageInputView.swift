//
//  MessageInputView.swift
//  myollama
//
//  Created by rtlink on 6/12/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PDFKit


struct MessageInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var selectedModel: String?
    @Binding var isGenerating: Bool
    
    @State private var selectedPDFText: String?
    @State private var selectedTXTText: String?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var showCamera: Bool = false
    @State private var showDocumentPicker: Bool = false

    @FocusState private var isTextFieldFocused: Bool
    
    let onSendMessage: () -> Void
    let onCancelGeneration: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let image = viewModel.selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.selectedImage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            HStack(spacing: 8) {
                TextField("l_input_message".localized, text: $viewModel.messageText, axis: .vertical)
                    .font(.system(size: 16))
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...5)
                
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    if isGenerating {
                        onCancelGeneration()
                    } else {
                        onSendMessage()
                    }
                }) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating)
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Divider(), alignment: .top
            )
        }
        .confirmationDialog("Add Content", isPresented: $showingActionSheet) {
            Button("l_photo_library".localized) {
                showingImagePicker = true
            }
            Button("l_take_photo".localized) {
                showCamera = true
            }
            Button("l_choose_files".localized) {
                showDocumentPicker = true
            }
            Button("l_cancel".localized, role: .cancel) {}
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: $viewModel.selectedImage)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(selectedImage: $viewModel.selectedImage, selectedPDFText: $selectedPDFText, selectedTXTText: $selectedTXTText)
        }
        .onReceive(viewModel.$shouldFocusTextField) { shouldFocus in
            if shouldFocus {
                isTextFieldFocused = true
                DispatchQueue.main.async {
                    viewModel.shouldFocusTextField = false
                }
            }
        }
        .onChange(of: selectedPDFText) { pdfText in
            if let pdfText = pdfText {
                Task { @MainActor in
                    viewModel.messageText += "\n\n[PDF]\n" + pdfText
                    selectedPDFText = nil
                }
            }
        }
        .onChange(of: selectedTXTText) { txtText in
            if let txtText = txtText {
                Task { @MainActor in
                    viewModel.messageText += "\n\n[TEXT]\n" + txtText
                    selectedTXTText = nil
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}


struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var selectedPDFText: String?
    @Binding var selectedTXTText: String?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.pdf,
            UTType.text,
            UTType.plainText,
            UTType.rtf,
            UTType.image,
            UTType.jpeg,
            UTType.png
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        private func resizeImage(_ image: UIImage, targetWidth: CGFloat = 800) -> UIImage {
            let size = image.size
            
            if size.width <= targetWidth {
                return image
            }
            
            let widthRatio = targetWidth / size.width
            let newHeight = size.height * widthRatio
            let newSize = CGSize(width: targetWidth, height: newHeight)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
            
            return resizedImage
        }
        
        private func extractTextFromPDF(url: URL) -> String? {
            guard let pdfDocument = PDFDocument(url: url) else {
                print("Failed to create PDF document from URL")
                return nil
            }
            
            var extractedText = ""
            let pageCount = pdfDocument.pageCount
            
            for pageIndex in 0..<pageCount {
                guard let page = pdfDocument.page(at: pageIndex) else { continue }
                if let pageText = page.string {
                    extractedText += pageText + "\n"
                }
            }
            
            return extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : extractedText
        }
        
        private func extractTextFromFile(url: URL) -> String? {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content
            } catch {
                print("Failed to read text file: \(error.localizedDescription)")
                do {
                    let content = try String(contentsOf: url, encoding: .utf16)
                    return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content
                } catch {
                    print("Failed to read text file with UTF-16: \(error.localizedDescription)")
                    return nil
                }
            }
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            print("file name: \(url.lastPathComponent)")
            print("file type: \(url.pathExtension)")
            
            let fileExtension = url.pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                        
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                parent.dismiss()
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            if imageExtensions.contains(fileExtension) {
                
                if let imageData = try? Data(contentsOf: url),
                   let image = UIImage(data: imageData) {
                    let resizedImage = resizeImage(image)
                    DispatchQueue.main.async {
                        self.parent.selectedImage = resizedImage
                    }
                } else {
                    print("Failed to load image data or create UIImage")
                }
            } else if fileExtension == "pdf" {
                
                if let extractedText = extractTextFromPDF(url: url) {
                    DispatchQueue.main.async {
                        self.parent.selectedPDFText = extractedText
                    }
                } else {
                    print("Failed to extract text from PDF")
                }
            } else if fileExtension == "txt" {
                
                if let extractedText = extractTextFromFile(url: url) {
                    DispatchQueue.main.async {
                        self.parent.selectedTXTText = extractedText
                    }
                } else {
                    print("Failed to read text from TXT file")
                }
            } else {
                print("Not a supported file type")
            }
            
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
