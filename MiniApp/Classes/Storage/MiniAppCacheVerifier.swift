import CommonCrypto
import RSDKUtils

internal class MiniAppCacheVerifier {
    let keystore = KeyStore()

    func verify(appId: String) -> Bool {
        let cachedFilesHash = calculateHash(appId: appId)
        let storedHash = keystore.key(for: appId) ?? ""

        return cachedFilesHash == storedHash
    }

    func storeHash(for appId: String) {
        keystore.removeKey(for: appId)
        keystore.addKey(key: calculateHash(appId: appId), for: appId)
    }

    private func calculateHash(appId: String) -> String {
        guard let directory = FileManager.getMiniAppVersionDirectory(usingAppId: appId) else {
            return ""
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
            options: [],
            errorHandler: { (url, error) -> Bool in
                MiniAppLogger.e("There was an error while processing the Mini App files \(url.absoluteString) so hash generation has failed.", error)
                return false
            }) else {
            return ""
        }

        var hash = ""
        for case let url as URL in enumerator {
            if url.hasDirectoryPath {
                continue
            }

            hash += sha512(url: url)
        }

        return sha512(string: hash)
    }

    private func sha512(string: String) -> String {
        guard let messageData = string.data(using: String.Encoding.utf8) else { return "" }
        var digestData = Data(count: Int(CC_SHA512_DIGEST_LENGTH))

        _ = digestData.withUnsafeMutableBytes { (digestBytes) -> Bool in
            messageData.withUnsafeBytes({ (messageBytes) -> Bool in
                _ = CC_SHA512(messageBytes.baseAddress, CC_LONG(messageData.count), digestBytes.bindMemory(to: UInt8.self).baseAddress)
                return true
            })
        }

        return digestData.base64EncodedString()
    }

    private func sha512(url: URL) -> String {
        do {
            let bufferSize = 1024 * 1024
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }

            var context = CC_SHA512_CTX()
            CC_SHA512_Init(&context)

            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    _ = data.withUnsafeBytes { (digestBytes) -> Bool in
                        _ = CC_SHA512_Update(&context, digestBytes.bindMemory(to: UInt8.self).baseAddress, numericCast(data.count))
                        return true
                    }
                    return true
                } else {
                    return false
                }
            }) { }

            var digest = Data(count: Int(CC_SHA512_DIGEST_LENGTH))
            _ = digest.withUnsafeMutableBytes { (digestBytes) -> Bool in
                _ = CC_SHA512_Final(digestBytes.bindMemory(to: UInt8.self).baseAddress, &context)
                return true
            }

            return digest.base64EncodedString()
        } catch {
            MiniAppLogger.e("Failed to calculate sha512 hash for Mini App files.")
            return ""
        }
    }
}