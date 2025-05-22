import UIKit

class DetailedImageTableViewCell: UITableViewCell {

    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.textColor = .label
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    let photoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5

        return imageView
    }()

    let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Зберегти фото", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        button.setTitleColor(.black, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        return button
    }()

    private var currentImageUrlString: String?
    private var networkManager: NetworkManager?
    private var imageCacheManager: ImageCacheManager?
    var saveButtonAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        saveButton.addTarget(self, action: #selector(didTapSaveButton), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(photoImageView)
        contentView.addSubview(saveButton)

        let verticalPadding: CGFloat = 12
        let horizontalPaddingForTitle: CGFloat = 16
        let spacingAfterTitle: CGFloat = 8
        let spacingAfterImage: CGFloat = 12

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalPadding),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPaddingForTitle),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPaddingForTitle),

            photoImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: spacingAfterTitle),
            photoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            photoImageView.heightAnchor.constraint(equalTo: photoImageView.widthAnchor),

            saveButton.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: spacingAfterImage),
            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalPadding)
        ])
        
    }

    func configure(title: String,
                   imageUrlString: String,
                   imageCacheManager: ImageCacheManager,
                   networkManager: NetworkManager) {
        
        self.titleLabel.text = title
        self.currentImageUrlString = imageUrlString
        self.imageCacheManager = imageCacheManager
        self.networkManager = networkManager

        self.photoImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
        self.photoImageView.backgroundColor = .systemGray5

        loadImage(from: imageUrlString)
    }

    private func loadImage(from urlString: String) {
        imageCacheManager?.getImage(forKey: urlString) { [weak self] cachedImage in
            guard let self = self, self.currentImageUrlString == urlString else {
                return
            }
            if let image = cachedImage {
                DispatchQueue.main.async {
                    self.photoImageView.image = image
                    self.photoImageView.backgroundColor = .clear
                }
            } else {
                self.downloadImage(from: urlString)
            }
        }
    }

    private func downloadImage(from urlString: String) {
        guard let networkManager = self.networkManager else { return }
        networkManager.fetchImageData(urlString: urlString) { [weak self] result in
            guard let self = self, self.currentImageUrlString == urlString else {
                return
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let image = UIImage(data: data) {
                        self.photoImageView.image = image
                        self.photoImageView.backgroundColor = .clear
                        self.imageCacheManager?.setImage(image, forKey: urlString)
                    } else {
                        self.photoImageView.image = UIImage(systemName: "xmark.octagon.fill")
                        self.photoImageView.backgroundColor = .systemGray5
                    }
                case .failure(let error):
                    print("Error downloading image for \(urlString): \(error.localizedDescription)")
                    self.photoImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
                    self.photoImageView.backgroundColor = .systemGray5
                }
            }
        }
    }

    @objc private func didTapSaveButton() {
        saveButtonAction?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        photoImageView.image = nil
        photoImageView.backgroundColor = .systemGray5
        currentImageUrlString = nil
        saveButtonAction = nil
    }
}
