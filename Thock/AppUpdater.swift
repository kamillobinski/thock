
import Foundation

class AppUpdater {
    static let shared = AppUpdater()

    private init() {}

    func checkForUpdates(completion: @escaping (Result<Bool, Error>) -> Void) {
        let currentVersion = AppInfoHelper.appVersion

        guard !currentVersion.isEmpty else {
            completion(.failure(AppUpdaterError.currentVersionNotFound))
            return
        }

        let urlString = "https://api.github.com/repos/kamillobinski/thock/releases/latest"
        guard let url = URL(string: urlString) else {
            completion(.failure(AppUpdaterError.invalidURL))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(AppUpdaterError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let tagName = json["tag_name"] as? String {
                    let latestVersion = tagName.replacingOccurrences(of: "v", with: "")

                    let isUpdateAvailable = self.compareVersions(currentVersion, latestVersion)
                    completion(.success(isUpdateAvailable))
                } else {
                    completion(.failure(AppUpdaterError.jsonParsingFailed))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    private func compareVersions(_ current: String, _ latest: String) -> Bool {
        // Handles major.minor.patch
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        
        guard !currentComponents.isEmpty && !latestComponents.isEmpty else {
            return false
        }

        let maxCount = max(currentComponents.count, latestComponents.count)
        
        for i in 0..<maxCount {
            let currentValue = i < currentComponents.count ? currentComponents[i] : 0
            let latestValue = i < latestComponents.count ? latestComponents[i] : 0
            
            if latestValue > currentValue {
                return true
            } else if latestValue < currentValue {
                return false
            }
        }

        return false
    }

    enum AppUpdaterError: Error {
        case currentVersionNotFound
        case invalidURL
        case noData
        case jsonParsingFailed
    }
}
