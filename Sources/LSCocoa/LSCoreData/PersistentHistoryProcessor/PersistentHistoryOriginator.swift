//
//  File.swift
//  
//
//  Created by Patrick Fischer on 27.04.22.
//

import Foundation

/**
 Originator of persistent data, this specifies the participants of data synchronisation. Typically defined in an enum.
 
 
 This is used if you want to keep persistent data between different originators in sync. This could be for example between an iOS app and a watchOS extension.
  ````
 enum AppTarget:String, PersistentHistoryOriginator, CaseIterable {
     case iOS
     case watchOS
     
     var identifier: String {
         self.rawValue
     }
     
     var allOrignators: [PersistentHistoryOriginator] {
         Self.allCases
     }
 }
  ````
 */
public protocol PersistentHistoryOriginator {
    var identifier: String { get }
    var allOrignators: [PersistentHistoryOriginator] { get }
}
