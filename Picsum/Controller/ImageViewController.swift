import UIKit
import Photos

class ImageViewController: UITableViewController {

    private var imagesInfo: [ImageInfo] = []
    private var currentPage: Int = 1
    private let itemsPerPage: Int = 20
    private var isLoadingNextPage: Bool = false

    private let networkManager = NetworkManager.shared
    private let imageCacheManager = ImageCacheManager.shared

    private lazy var screenWidth: CGFloat = {
        return UIScreen.main.bounds.width
    }()

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Галерея Picsum"
        navigationController?.navigationBar.prefersLargeTitles = true
        setupTableView()
        requestPhotoLibraryAccessIfNeeded()
        loadImages(page: currentPage, showLoadingIndicator: true)
    }

    private func setupTableView() {
        tableView.register(DetailedImageTableViewCell.self, forCellReuseIdentifier: "DetailedImageCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = screenWidth + 120
    }

    private func loadImages(page: Int, showLoadingIndicator: Bool = false) {
        guard !isLoadingNextPage else { return }
        isLoadingNextPage = true
        networkManager.fetchImageList(page: page, limit: itemsPerPage) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoadingNextPage = false
                switch result {
                case .success(let newImagesInfo):
                    if newImagesInfo.isEmpty && page > 1 {
                        return
                    }
                    
                    let existingIDs = Set(self.imagesInfo.map { $0.id })
                    let uniqueNewImages = newImagesInfo.filter { !existingIDs.contains($0.id) }
                    
                    if page == 1 {
                        self.imagesInfo = uniqueNewImages
                        self.tableView.reloadData()
                    } else if !uniqueNewImages.isEmpty {
                        let currentCount = self.imagesInfo.count
                        self.imagesInfo.append(contentsOf: uniqueNewImages)
                        let newIndexPaths = (currentCount..<self.imagesInfo.count)
                            .map { IndexPath(row: $0, section: 0) }
                        self.tableView.insertRows(at: newIndexPaths, with: .automatic)
                    }
                    
                case .failure(let error):
                    self.showErrorAlert(message: "Не вдалося завантажити зображення: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showErrorAlert(title: String = "Помилка", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return imagesInfo.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "DetailedImageCell", for: indexPath) as? DetailedImageTableViewCell else {
            fatalError("Не вдалося деконструювати DetailedImageTableViewCell. Переконайтесь, що вона зареєстрована.")
        }

        let imageInfo = imagesInfo[indexPath.row]
        
        let imageDisplaySizeForURL = Int(screenWidth * UIScreen.main.scale)
        let imageUrlString = "https://picsum.photos/id/\(imageInfo.id)/\(imageDisplaySizeForURL)"

        cell.configure(
            title: "Автор: \(imageInfo.author)",
            imageUrlString: imageUrlString,
            imageCacheManager: imageCacheManager,
            networkManager: networkManager
        )

        cell.saveButtonAction = { [weak self, weak cell] in
            guard let self = self else { return }
            
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .authorized || status == .limited {
                guard let imageToSave = cell?.photoImageView.image else {
                    self.showErrorAlert(message: "Зображення ще не доступне для збереження. Зачекайте, поки воно завантажиться.")
                    return
                }
                self.saveImageToLibrary(imageToSave)
            } else {
                self.promptForPhotoLibraryAccess()
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastElementIndex = imagesInfo.count - 5
        if !isLoadingNextPage && indexPath.row >= lastElementIndex && imagesInfo.count > 0 && imagesInfo.count >= itemsPerPage * currentPage {
            currentPage += 1
            loadImages(page: currentPage)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let imageInfo = imagesInfo[indexPath.row]
        
        let fullScreenVC = FullScreenImageViewController()
        
        let maxScreenDimension = Int(max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale)
        fullScreenVC.imageUrlString = "https://picsum.photos/id/\(imageInfo.id)/\(maxScreenDimension)/\(maxScreenDimension)"
        fullScreenVC.imageTitle = "Автор: \(imageInfo.author)"
        
        navigationController?.pushViewController(fullScreenVC, animated: true)
    }
    
    private func requestPhotoLibraryAccessIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    completion?(newStatus == .authorized || newStatus == .limited)
                }
            }
        } else {
            completion?(status == .authorized || status == .limited)
        }
    }

    private func promptForPhotoLibraryAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .denied, .restricted:
            showPermissionErrorAlert()
        case .notDetermined:
            requestPhotoLibraryAccessIfNeeded { [weak self] granted in
                if !granted {
                    self?.showPermissionErrorAlert()
                }
            }
        default:
            break
        }
    }
    
    private func saveImageToLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.showSuccessAlert(message: "Зображення успішно збережено до вашої фотогалереї.")
                } else if let error = error {
                    self.showErrorAlert(message: "Не вдалося зберегти зображення: \(error.localizedDescription)")
                } else {
                    self.showErrorAlert(message: "Не вдалося зберегти зображення через невідому помилку.")
                }
            }
        }
    }
    
    private func showSuccessAlert(title: String = "Успіх", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showPermissionErrorAlert() {
        let alert = UIAlertController(
            title: "Доступ заборонено",
            message: "Щоб зберегти фото, будь ласка, надайте доступ до вашої фотогалереї в Налаштуваннях.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Скасувати", style: .cancel))
        alert.addAction(UIAlertAction(title: "Налаштування", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }))
        present(alert, animated: true)
    }
}
