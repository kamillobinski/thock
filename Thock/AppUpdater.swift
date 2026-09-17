
import Foundation

class AppUpdater {
    static let shared = AppUpdater()

    private init() {}

    func checkForUpdates(completion: @escaping (Result<Bool, Error>) -> Void) {
        let currentVersion = AppInfoHelper.appVersion

        guard !currentVersion.isEmpty else {
            deliver(.failure(AppUpdaterError.currentVersionNotFound), to: completion)
            return
        }

        let urlString = "https://api.github.com/repos/kamillobinski/thock/releases/latest"
        guard let url = URL(string: urlString) else {
            deliver(.failure(AppUpdaterError.invalidURL), to: completion)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                self.deliver(.failure(error), to: completion)
                return
            }

            guard let data = data else {
                self.deliver(.failure(AppUpdaterError.noData), to: completion)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let tagName = json["tag_name"] as? String {
                    let latestVersion = tagName.replacingOccurrences(of: "v", with: "")

                    let isUpdateAvailable = self.compareVersions(currentVersion, latestVersion)
                    self.deliver(.success(isUpdateAvailable), to: completion)
                } else {
                    self.deliver(.failure(AppUpdaterError.jsonParsingFailed), to: completion)
                }
            } catch {
                self.deliver(.failure(error), to: completion)
            }
        }
        task.resume()
    }

    /// Delivers a result on the main queue.
    ///
    /// URLSession calls its completion handler on a background queue while the early
    /// exits above ran on whatever thread called `checkForUpdates`, so callers had no
    /// single thread to rely on. The only caller updates the menu bar, which made the
    /// background delivery an off-main UI mutation. Delivering on main in one place
    /// gives the callback a contract instead of leaving it to each caller to guess.
    private func deliver(_ result: Result<Bool, Error>, to completion: @escaping (Result<Bool, Error>) -> Void) {
        DispatchQueue.main.async {
            completion(result)
        }
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
