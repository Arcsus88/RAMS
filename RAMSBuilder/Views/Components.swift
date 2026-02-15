import PhotosUI
import SwiftUI
import UIKit

extension Color {
    static let proSlate900 = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let proSlate800 = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    static let proSlate100 = Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255)
    static let proYellow = Color(red: 250 / 255, green: 204 / 255, blue: 21 / 255)
}

struct RiskReviewBadge: View {
    let review: RiskReview

    private var backgroundColor: Color {
        switch review {
        case .veryLow:
            return .green.opacity(0.2)
        case .low:
            return .mint.opacity(0.25)
        case .medium:
            return .yellow.opacity(0.25)
        case .high:
            return .orange.opacity(0.25)
        case .veryHigh:
            return .red.opacity(0.25)
        }
    }

    private var foregroundColor: Color {
        switch review {
        case .veryLow, .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .veryHigh:
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(review.rawValue)
                .font(.headline.weight(.semibold))
            Text(review.title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}

struct MapImagePickerView: View {
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Site / Hospital Map")
                .font(.subheadline.weight(.semibold))

            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.2))
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 120)
                    .overlay(
                        Text("Add map image")
                            .foregroundStyle(.secondary)
                    )
            }

            HStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label("Select Map Image", systemImage: "photo")
                }

                if imageData != nil {
                    Button(role: .destructive) {
                        imageData = nil
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    imageData = data
                }
            }
        }
    }
}

private struct SignatureStroke {
    var points: [CGPoint] = []
}

struct SignaturePadView: View {
    @Binding var signatureImageData: Data?

    @State private var strokes: [SignatureStroke] = []
    @State private var currentStroke = SignatureStroke()
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Digital Signature")
                .font(.subheadline.weight(.semibold))

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)

                    Path { path in
                        for stroke in strokes {
                            guard let firstPoint = stroke.points.first else { continue }
                            path.move(to: firstPoint)
                            for point in stroke.points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }

                        if let firstPoint = currentStroke.points.first {
                            path.move(to: firstPoint)
                            for point in currentStroke.points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(Color.black, lineWidth: 2.0)
                }
                .onAppear {
                    canvasSize = proxy.size
                }
                .onChange(of: proxy.size) { _, newSize in
                    canvasSize = newSize
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if currentStroke.points.isEmpty {
                                currentStroke.points = [gesture.location]
                            } else {
                                currentStroke.points.append(gesture.location)
                            }
                        }
                        .onEnded { _ in
                            strokes.append(currentStroke)
                            currentStroke = SignatureStroke()
                            signatureImageData = renderSignature(size: canvasSize)
                        }
                )
            }
            .frame(height: 170)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2))
            )

            HStack {
                Button("Clear Signature", role: .destructive) {
                    strokes = []
                    currentStroke = SignatureStroke()
                    signatureImageData = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(signatureImageData == nil ? "Not saved" : "Ready")
                    .font(.caption)
                    .foregroundColor(signatureImageData == nil ? .secondary : .green)
            }
        }
    }

    private func renderSignature(size: CGSize) -> Data? {
        guard size.width > 0, size.height > 0, !strokes.isEmpty else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.setStrokeColor(UIColor.black.cgColor)
            context.cgContext.setLineWidth(2.0)
            context.cgContext.setLineCap(.round)

            for stroke in strokes where !stroke.points.isEmpty {
                context.cgContext.beginPath()
                context.cgContext.move(to: stroke.points[0])
                for point in stroke.points.dropFirst() {
                    context.cgContext.addLine(to: point)
                }
                context.cgContext.strokePath()
            }
        }

        return image.pngData()
    }
}

struct HazardTemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category = ""
    @State private var title = ""
    @State private var riskTo = ""
    @State private var controlMeasuresText = ""
    @State private var initialLikelihood = 3
    @State private var initialSeverity = 3
    @State private var residualLikelihood = 2
    @State private var residualSeverity = 2

    let onSave: (HazardTemplate) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Hazard details") {
                    TextField("Category", text: $category)
                    TextField("Hazard title", text: $title)
                    TextField("Risk to", text: $riskTo)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Control measures (one per line)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $controlMeasuresText)
                            .frame(minHeight: 90)
                    }
                }

                Section("Default scoring") {
                    Stepper("Initial likelihood: \(initialLikelihood)", value: $initialLikelihood, in: 1...5)
                    Stepper("Initial severity: \(initialSeverity)", value: $initialSeverity, in: 1...5)
                    Stepper("Residual likelihood: \(residualLikelihood)", value: $residualLikelihood, in: 1...5)
                    Stepper("Residual severity: \(residualSeverity)", value: $residualSeverity, in: 1...5)
                }
            }
            .navigationTitle("Add Hazard Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let controls = controlMeasuresText
                            .split(separator: "\n")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }

                        let template = HazardTemplate(
                            id: UUID(),
                            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            riskToDefault: riskTo.trimmingCharacters(in: .whitespacesAndNewlines),
                            controlMeasuresDefault: controls,
                            defaultInitialLikelihood: initialLikelihood,
                            defaultInitialSeverity: initialSeverity,
                            defaultResidualLikelihood: residualLikelihood,
                            defaultResidualSeverity: residualSeverity
                        )
                        onSave(template)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
