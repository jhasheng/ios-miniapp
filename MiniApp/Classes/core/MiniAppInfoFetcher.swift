internal class MiniAppInfoFetcher {

    func fetchList(apiClient: MiniAppClient, completionHandler: @escaping (Result<[MiniAppInfo], Error>) -> Void) {

        apiClient.getMiniAppsList { (result) in
            switch result {
            case .success(let responseData):
                guard let decodeResponse = ResponseDecoder.decode(decodeType: Array<MiniAppInfo>.self, data: responseData.data) else {
                    return completionHandler(.failure(NSError.invalidResponseData()))
                }
                return completionHandler(.success(decodeResponse))
            case .failure(let error):
                return completionHandler(.failure(error))
            }
        }
    }

    func getInfo(miniAppId: String, miniAppVersion: String? = nil, apiClient: MiniAppClient, completionHandler: @escaping (Result<MiniAppInfo, Error>) -> Void) {

        apiClient.getMiniApp(miniAppId) { (result) in
            switch result {
            case .success(let responseData):
                if let decodeResponse = ResponseDecoder.decode(decodeType: Array<MiniAppInfo>.self, data: responseData.data) {
                    let miniAppInfo: MiniAppInfo?
                    if let version = miniAppVersion {
                        miniAppInfo = decodeResponse.filter({ (appInfo) -> Bool in
                            appInfo.version.versionId == version
                        }).first
                    } else {
                        miniAppInfo = decodeResponse.first
                    }
                    if let miniApp = miniAppInfo {
                        return completionHandler(.success(miniApp))
                    } else {
                        return completionHandler(.failure(NSError.noPublishedVersion()))
                    }
                }
                return completionHandler(.failure(NSError.invalidResponseData()))
            case .failure(let error):
                return completionHandler(.failure(error))
            }
        }
    }

    func getMiniAppMetaInfo(miniAppId: String, miniAppVersion: String, apiClient: MiniAppClient, completionHandler: @escaping (Result<MiniAppManifest, MASDKError>) -> Void) {

        apiClient.getMiniAppMetaData(appId: miniAppId, versionId: miniAppVersion) { (result) in
            switch result {
            case .success(let responseData):
                guard let decodeResponse = ResponseDecoder.decode(decodeType: MetaDataResponse.self,
                    data: responseData.data) else {
                    return completionHandler(.failure(.invalidResponseData))
                }
                return completionHandler(.success(
                                            self.prepareMiniAppManifest(
                                                metaDataResponse: decodeResponse.bundleManifest,
                                                versionId: miniAppVersion)))
            case .failure(let error):
                return completionHandler(.failure(.fromError(error: error)))
            }
        }
    }

    func prepareMiniAppManifest(metaDataResponse: MetaDataCustomPermissionModel, versionId: String) -> MiniAppManifest {
        return MiniAppManifest(requiredPermissions: getCustomPermissionModel(metaDataCustomPermissionResponse: metaDataResponse.reqPermissions),
            optionalPermissions: getCustomPermissionModel(
                metaDataCustomPermissionResponse: metaDataResponse.optPermissions),
            customMetaData: metaDataResponse.customMetaData,
            versionId: versionId)
    }

    private func getCustomPermissionModel(metaDataCustomPermissionResponse: [MACustomPermissionsResponse]?) -> [MASDKCustomPermissionModel]? {
        return metaDataCustomPermissionResponse?.compactMap {
            guard let name = $0.name, let permissionType = MiniAppCustomPermissionType(rawValue: name) else {
                return nil
            }
            return MASDKCustomPermissionModel(permissionName: permissionType, isPermissionGranted: .allowed, permissionRequestDescription: $0.reason)
        }
    }
}
