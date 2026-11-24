// Lifts the subject out of a painting with Vision (the same model as
// "Copy Subject" in Photos) and writes it as a transparent PNG.
//
//   swift scripts/cutout.swift <input.png> <output.png>
import AppKit
import CoreImage
import Vision

let args = CommandLine.arguments
guard args.count == 3 else {
    print("usage: cutout.swift <input.png> <output.png>")
    exit(1)
}
let input = URL(filePath: args[1])
let output = URL(filePath: args[2])

guard let image = CIImage(contentsOf: input) else {
    print("✗ cannot read \(input.path)")
    exit(1)
}

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(ciImage: image)
do {
    try handler.perform([request])
    guard let result = request.results?.first else {
        print("✗ no subject found")
        exit(1)
    }
    let masked = try result.generateMaskedImage(
        ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false)
    let cut = CIImage(cvPixelBuffer: masked)
    let context = CIContext()
    try context.writePNGRepresentation(
        of: cut, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    print("✓ cutout → \(output.path)")
} catch {
    print("✗ \(error.localizedDescription)")
    exit(1)
}
