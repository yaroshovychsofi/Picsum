import UIKit

class ImageCacheManager {

    static let shared = ImageCacheManager()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    private let diskAccessQueue = DispatchQueue(label: "com.picsumapp.imageCache.diskAccess", qos: .background)

    private init() {
        guard let baseCacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Caches directory.")
        }
        diskCacheDirectory = baseCacheDirectory.appendingPathComponent("ImageCache")
        createDiskCacheDirectoryIfNeeded()
    }

    private func createDiskCacheDirectoryIfNeeded() {
        diskAccessQueue.async {
            if !self.fileManager.fileExists(atPath: self.diskCacheDirectory.path) {
                do {
                    try self.fileManager.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true, attributes: nil)
                    print("Disk cache directory created at: \(self.diskCacheDirectory.path)")
                } catch {
                    print("Error creating disk cache directory: \(error.localizedDescription)")
                }
            }
        }
    }

    func getImage(forKey key: String, completion: @escaping (UIImage?) -> Void) {
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        diskAccessQueue.async {
            let fileURL = self.fileURLForKey(key)
            if self.fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let data = try Data(contentsOf: fileURL)
                    if let image = UIImage(data: data) {
                        self.memoryCache.setObject(image, forKey: key as NSString)
                        DispatchQueue.main.async {
                            completion(image)
                        }
                        return
                    } else {
                        print("ImageCacheManager: Error creating UIImage from disk data for key '\(key)'. Removing corrupted file.")
                        try? self.fileManager.removeItem(at: fileURL)
                    }
                } catch {
                    print("ImageCacheManager: Error reading image data from disk for key '\(key)': \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }

    func setImage(_ image: UIImage, forKey key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
        // print("ImageCacheManager: Set Memory for \(key.suffix(20))")

        diskAccessQueue.async {
            let fileURL = self.fileURLForKey(key)
            guard let data = image.jpegData(compressionQuality: 0.85) else {
                print("ImageCacheManager: Error: Could not get JPEG data for image with key '\(key)'.")
                return
            }

            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("ImageCacheManager: Error saving image to disk for key '\(key)': \(error.localizedDescription)")
            }
        }
    }

    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        print("ImageCacheManager: Memory cache cleared.")
    }

    func clearDiskCache(completion: (() -> Void)? = nil) {
        diskAccessQueue.async {
            do {
                if self.fileManager.fileExists(atPath: self.diskCacheDirectory.path) {
                    try self.fileManager.removeItem(at: self.diskCacheDirectory)
                    print("ImageCacheManager: Disk cache directory removed.")
                    self.createDiskCacheDirectoryIfNeeded()
                } else {
                    print("ImageCacheManager: Disk cache directory does not exist, no need to clear.")
                }
            } catch {
                print("ImageCacheManager: Error clearing disk cache: \(error.localizedDescription)")
            }
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    func clearAllCache(completion: (() -> Void)? = nil) {
        clearMemoryCache()
        clearDiskCache(completion: completion)
    }

    private func fileURLForKey(_ key: String) -> URL {
        let allowedCharacters = CharacterSet.alphanumerics
        let sanitizedKey = key.unicodeScalars.map {
            allowedCharacters.contains($0) ? String($0) : "_"
        }.joined()
        
        let maxLength = 100
        let finalFileName = sanitizedKey.count > maxLength ? String(sanitizedKey.prefix(maxLength)) : sanitizedKey
        
        return diskCacheDirectory.appendingPathComponent(finalFileName + ".jpg")
    }
}
