//
//  SwiftfulDataManagers+Alias.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/02/2026.
//

import SwiftUI

import SwiftfulDataManagers
import SwiftfulDataManagersFirebase

typealias DocumentSyncEngine = SwiftfulDataManagers.DocumentSyncEngine
typealias CollectionSyncEngine = SwiftfulDataManagers.CollectionSyncEngine
typealias CollectionGroupSyncEngine = SwiftfulDataManagers.CollectionGroupSyncEngine
typealias DataSyncModelProtocol = SwiftfulDataManagers.DataSyncModelProtocol
typealias FirebaseRemoteDocumentService = SwiftfulDataManagersFirebase.FirebaseRemoteDocumentService
typealias FirebaseRemoteCollectionService = SwiftfulDataManagersFirebase.FirebaseRemoteCollectionService
typealias FirebaseRemoteCollectionGroupService = SwiftfulDataManagersFirebase.FirebaseRemoteCollectionGroupService
typealias MockRemoteDocumentService = SwiftfulDataManagers.MockRemoteDocumentService
typealias MockRemoteCollectionService = SwiftfulDataManagers.MockRemoteCollectionService
typealias MockRemoteCollectionGroupService = SwiftfulDataManagers.MockRemoteCollectionGroupService
typealias QueryBuilder = SwiftfulDataManagers.QueryBuilder

typealias LocalDocumentPersistence = SwiftfulDataManagers.LocalDocumentPersistence
typealias MockLocalDocumentPersistence = SwiftfulDataManagers.MockLocalDocumentPersistence
typealias FileManagerDocumentPersistence = SwiftfulDataManagers.FileManagerDocumentPersistence

typealias LocalCollectionPersistence = SwiftfulDataManagers.LocalCollectionPersistence
typealias MockLocalCollectionPersistence = SwiftfulDataManagers.MockLocalCollectionPersistence
typealias SwiftDataCollectionPersistence = SwiftfulDataManagers.SwiftDataCollectionPersistence

typealias DMCodableSendable = SwiftfulDataManagers.DMCodableSendable

extension Date: @retroactive DMCodableSendable { }

extension DataLogType {
    
    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .severe:
            return .severe
        }
    }
}

extension LogManager: @retroactive DataSyncLogger {
    public func trackEvent(event: any DataSyncLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }
}
