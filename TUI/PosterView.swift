import SwiftUI

struct PosterView: View {
    let photo: Photo
    let displayWidth: CGFloat = 380
    let highResWidth: CGFloat = 1920
    @State private var canvasHeight: CGFloat = 380
    @State private var imageLoadError: String?
    @Binding var processedImage: UIImage?
    @Binding var originalImage: UIImage?
    let isBirdSpecies: Bool
    let birdNumber: Int?
    @Binding var shouldRegenerate: Bool
    @State private var processedTitle: String = ""
    @AppStorage("shareWithExif") private var shareWithExif = false
    @AppStorage("shareWithGPS") private var shareWithGPS = false
    @AppStorage("omitCameraBrand") private var omitCameraBrand = false
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    
    // 新增保存圖像的閉包
    let saveImage: (UIImage) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Group {
                if let error = imageLoadError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if let uiImage = processedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: canvasHeight)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                } else {
                    ProgressView()
                }
            }
        }
        .frame(width: displayWidth, height: canvasHeight)
        .background(Color.clear)
        .onAppear {
            loadAndProcessImage()
        }
        .onChange(of: shouldRegenerate) { oldValue, newValue in
            if newValue {
                loadAndProcessImage()
                shouldRegenerate = false
            }
        }
    }
    
    func loadAndProcessImage() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(photo.path).path
        
        if fileManager.fileExists(atPath: fullPath) {
            if let uiImage = UIImage(contentsOfFile: fullPath) {
                self.originalImage = uiImage
                
                let aspectRatio = uiImage.size.width / uiImage.size.height
                let scaledImageHeight = highResWidth / aspectRatio
                
                let additionalInfoHeight = highResWidth * (128.0 / 380.0)
                let newCanvasHeight = scaledImageHeight + additionalInfoHeight
                
                if let processedUIImage = addWhiteCanvas(to: uiImage, canvasHeight: newCanvasHeight, canvasWidth: highResWidth) {
                    DispatchQueue.main.async {
                        self.canvasHeight = (newCanvasHeight / highResWidth) * displayWidth
                        self.processedImage = processedUIImage
                    }
                } else {
                    DispatchQueue.main.async {
                        self.imageLoadError = "Image processing failed"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.imageLoadError = "Unable to create UIImage from file"
                }
            }
        } else {
            DispatchQueue.main.async {
                self.imageLoadError = "File does not exist at path: \(fullPath)"
            }
        }
    }
    
    private func addWhiteCanvas(to image: UIImage, canvasHeight: CGFloat, canvasWidth: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        if let bgColor = UIColor(named: "BGColor") {
            context.setFillColor(bgColor.cgColor)
        } else {
            context.setFillColor(UIColor.white.cgColor)
        }
        context.fill(CGRect(origin: .zero, size: canvasSize))
        
        let aspectRatio = image.size.width / image.size.height
        let drawSize = CGSize(width: canvasSize.width, height: canvasSize.width / aspectRatio)
        let drawOrigin = CGPoint(x: 0, y: 0)
        
        let drawRect = CGRect(origin: drawOrigin, size: drawSize)
        image.draw(in: drawRect)
        
        let infoOriginY = drawSize.height + 10
        addImageInfo(context: context, originY: infoOriginY, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        
        if let tuiAppImage = UIImage(named: "tuiapp") {
            let iconSize: CGFloat = canvasWidth / 12
            let padding: CGFloat = canvasWidth / 60
            let iconRect = CGRect(x: canvasSize.width - iconSize - padding,
                                  y: canvasSize.height - iconSize - padding,
                                  width: iconSize,
                                  height: iconSize)
            tuiAppImage.draw(in: iconRect)
        }
        
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        return newImage
    }
    
    @AppStorage("userName") private var userName: String = "Tui"
    
    private func addImageInfo(context: CGContext, originY: CGFloat, canvasWidth: CGFloat, canvasHeight: CGFloat) {
        let imageHeight = originY - 10
        let additionalHeight = canvasHeight - imageHeight
        let scaleFactor = additionalHeight / 128
        
        let titleFontSize: CGFloat = 24 * scaleFactor
        let infoFontSize: CGFloat = 20 * scaleFactor
        let lineHeight: CGFloat = 26 * scaleFactor
        let leftMargin: CGFloat = 14 * scaleFactor
        
        let titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .regular)
        let infoFont = UIFont.systemFont(ofSize: infoFontSize, weight: .thin)
        
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .center
        
        let infoParagraphStyle = NSMutableParagraphStyle()
        infoParagraphStyle.alignment = .left
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .paragraphStyle: titleParagraphStyle,
            .foregroundColor: UIColor.black
        ]
        
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .paragraphStyle: infoParagraphStyle,
            .foregroundColor: UIColor.black
        ]
        
        var photoTitle = !photo.objectName.isEmpty ? photo.objectName :
        !photo.title.isEmpty ? photo.title :
        "Untitled Photo"
        
        if enableBirdWatching && isBirdSpecies, let number = birdNumber {
            photoTitle = "No.\(number) \(photoTitle)"
        }
        
        processedTitle = photoTitle
        
        let titleSpacing = lineHeight * 1.5
        
        photoTitle.draw(with: CGRect(x: 0, y: originY, width: canvasWidth, height: titleSpacing),
                        options: .usesLineFragmentOrigin,
                        attributes: titleAttributes,
                        context: nil)
        
        let infoOriginY = originY + titleSpacing
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var dateAndLocation = "\(userName) • "
        if let date = dateFormatter.date(from: photo.dateTimeOriginal) {
            dateFormatter.dateFormat = "yy-MM-dd"
            let formattedDate = dateFormatter.string(from: date)
            dateAndLocation += "\(formattedDate)"
        }
        if shareWithGPS && !photo.locality.isEmpty {
            dateAndLocation += " • \(photo.locality), \(photo.area), \(photo.country)"
        }
        
        dateAndLocation.draw(with: CGRect(x: leftMargin, y: infoOriginY, width: canvasWidth - leftMargin * 2, height: lineHeight),
                             options: .usesLineFragmentOrigin,
                             attributes: infoAttributes,
                             context: nil)
        
        let cameraInfo = formatCameraInfo()
        
        cameraInfo.draw(with: CGRect(x: leftMargin, y: infoOriginY + lineHeight, width: canvasWidth - leftMargin * 2, height: lineHeight),
                        options: .usesLineFragmentOrigin,
                        attributes: infoAttributes,context: nil)
        
        let captionOrExif: String
        if shareWithExif {
            captionOrExif = formatExifInfo()
        } else if !photo.caption.isEmpty {
            captionOrExif = photo.caption.components(separatedBy: .newlines).first ?? ""
        } else {
            captionOrExif = QuoteManager.shared.getTodaysQuote()
        }
        
        let truncatedCaptionOrExif = truncateString(captionOrExif, width: canvasWidth - leftMargin * 2, font: infoFont)
        
        truncatedCaptionOrExif.draw(with: CGRect(x: leftMargin, y: infoOriginY + lineHeight * 2, width: canvasWidth - leftMargin * 2, height: lineHeight),
                                    options: .usesLineFragmentOrigin,
                                    attributes: infoAttributes,
                                    context: nil)
    }
    
    private func formatCameraInfo() -> String {
        let cameraModel = omitCameraBrand ? removeBrandName(from: photo.model) : photo.model
        let lensModel = omitCameraBrand ? removeBrandName(from: photo.lensModel) : photo.lensModel
        return "\(cameraModel) - \(lensModel)"
    }
    
    private func removeBrandName(from model: String) -> String {
        let brandNames = ["Nikon", "Canon", "Sony", "Fujifilm", "Panasonic", "Olympus", "Leica", "Hasselblad", "Pentax", "Sigma", "Tamron", "Zeiss", "Nikkor"]
        var result = model
        
        for brand in brandNames {
            if result.lowercased().contains(brand.lowercased()) {
                result = result.replacingOccurrences(of: brand, with: "", options: [.caseInsensitive, .anchored])
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                break  // 只移除第一个匹配的品牌名
            }
        }
        
        return result
    }
    
    private func formatExifInfo() -> String {
        var exifInfo = [String]()
        if enableBirdWatching && isBirdSpecies, let number = birdNumber {
            exifInfo.append("Bird ID: No.\(number)")
        }
        if photo.fNumber != 0 {
            exifInfo.append(String(format: "f/%.1f", photo.fNumber))
        }
        if photo.exposureTime != 0 {
            let exposureTimeString: String
            if photo.exposureTime < 1 {
                exposureTimeString = "1/\(Int(round(1/photo.exposureTime)))"
            } else {
                exposureTimeString = String(format: "%.1f", photo.exposureTime)
            }
            exifInfo.append("\(exposureTimeString)s")
        }
        if photo.ISOSPEEDRatings != 0 {
            exifInfo.append("ISO \(photo.ISOSPEEDRatings)")
        }
        if photo.focalLenIn35mmFilm != 0 {
            exifInfo.append(String(format: "%.0fmm", photo.focalLenIn35mmFilm))
        }
        
        return exifInfo.joined(separator: " • ")
    }
    
    private func truncateString(_ string: String, width: CGFloat, font: UIFont) -> String {
        let attributedString = NSAttributedString(string: string, attributes: [.font: font])
        let boundingRect = attributedString.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                         options: .usesLineFragmentOrigin,
                                                         context: nil)
        
        if boundingRect.width > width {
            var truncatedString = string
            var range = NSRange(location: 0, length: string.count)
            
            while range.length > 0 {
                range = (string as NSString).rangeOfComposedCharacterSequence(at: range.length - 1)
                truncatedString = (string as NSString).substring(to: range.location)
                
                let attributedTruncatedString = NSAttributedString(string: truncatedString + "...", attributes: [.font: font])
                let truncatedRect = attributedTruncatedString.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                                           options: .usesLineFragmentOrigin,
                                                                           context: nil)
                
                if truncatedRect.width <= width {
                    return truncatedString + "..."
                }
            }
        }
        
        return string
    }
}
