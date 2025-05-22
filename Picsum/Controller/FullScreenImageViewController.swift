import UIKit

class FullScreenImageViewController: UIViewController, UIScrollViewDelegate {

    var imageUrlString: String?
    var imageTitle: String?

    private let networkManager = NetworkManager.shared
    private let imageCacheManager = ImageCacheManager.shared

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var activityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupScrollView()
        setupImageView()
        setupActivityIndicator()
        setupGestureRecognizers()

        loadImage()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if imageView.image != nil {
            updateZoomScalesAndResetZoom(animated: false)
        }
    }

    private func setupNavigationBar() {
        navigationItem.title = imageTitle ?? "Зображення"
        navigationItem.largeTitleDisplayMode = .never
    }

    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupImageView() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        scrollView.addSubview(imageView)
    }

    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .gray
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupGestureRecognizers() {
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapRecognizer)
    }

    private func loadImage() {
        guard let urlString = imageUrlString else {
            print("Помилка: imageUrlString для FullScreenImageViewController є nil.")
            imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")?
                .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            imageView.contentMode = .center
            return
        }

        activityIndicator.startAnimating()
        view.bringSubviewToFront(activityIndicator)

        imageCacheManager.getImage(forKey: urlString) { [weak self] cachedImage in
            guard let self = self else { return }

            if let image = cachedImage {
                DispatchQueue.main.async {
                    self.displayImage(image)
                }
                return
            }

            self.networkManager.fetchImageData(urlString: urlString) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        if let image = UIImage(data: data) {
                            self.displayImage(image)
                            self.imageCacheManager.setImage(image, forKey: urlString)
                        } else {
                            print("Помилка: не вдалося створити UIImage з отриманих даних для URL: \(urlString)")
                            self.activityIndicator.stopAnimating()
                            self.imageView.image = UIImage(systemName: "xmark.octagon.fill")?
                                .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
                            self.imageView.contentMode = .center
                        }
                    case .failure(let error):
                        print("Помилка завантаження зображення для повноекранного перегляду (URL: \(urlString)): \(error.localizedDescription)")
                        self.activityIndicator.stopAnimating()
                        self.imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")?
                            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
                        self.imageView.contentMode = .center
                    }
                }
            }
        }
    }

    private func displayImage(_ image: UIImage) {
        activityIndicator.stopAnimating()
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
        updateZoomScalesAndResetZoom(animated: false)
    }

    private func updateZoomScalesAndResetZoom(animated: Bool) {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else {
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = 1.0
            scrollView.zoomScale = 1.0
            scrollView.contentSize = .zero
            imageView.frame = .zero
            return
        }

        let scrollViewBounds = scrollView.bounds
        guard scrollViewBounds.width > 0, scrollViewBounds.height > 0 else { return }

        let widthScale = scrollViewBounds.width / image.size.width
        let heightScale = scrollViewBounds.height / image.size.height
        
        let minScale = min(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 3.0, 3.0)
        scrollView.setZoomScale(minScale, animated: animated)
        centerImageViewIfNeeded()
    }
    
    private func centerImageViewIfNeeded() {
        guard imageView.image != nil else { return }

        let scrollViewBounds = scrollView.bounds
        let contentSize = scrollView.contentSize

        let offsetX = max((scrollViewBounds.width - contentSize.width) * 0.5, 0)
        let offsetY = max((scrollViewBounds.height - contentSize.height) * 0.5, 0)
        
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageViewIfNeeded()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale <= scrollView.minimumZoomScale * 1.05 {
            let pointInView = recognizer.location(in: imageView)
            let newZoomScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.5)
            let scrollViewSize = scrollView.bounds.size
            let width = scrollViewSize.width / newZoomScale
            let height = scrollViewSize.height / newZoomScale
            let x = pointInView.x - (width / 2.0)
            let y = pointInView.y - (height / 2.0)
            let rectToZoomTo = CGRect(x: x, y: y, width: width, height: height)
            scrollView.zoom(to: rectToZoomTo, animated: true)
        } else {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        }
    }
}
