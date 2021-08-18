//
//  Response.swift
//  VT_final
//
//  Created by Andi Xu on 8/17/21.
//

import Foundation

struct FlickrResponse: Codable {
    
    let photos: PhotosResponse
    let stat: String
    
    enum CodingKeys: String, CodingKey {
        case photos
        case stat
    }
}

struct PhotosResponse: Codable {
    
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int
    let photo: [FlickrPhoto]
    
    enum CodingKeys: String, CodingKey {
        case page
        case pages
        case perPage = "perpage"
        case total
        case photo
    }
}

struct FlickrPhoto: Codable {
    
    let id: String
    let owner: String
    let secret: String
    let server: String
    let farm: Int
    let title: String
    let isPublic: Int
    let isFriend: Int
    let isFamily: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case owner
        case secret
        case server
        case farm
        case title
        case isPublic = "ispublic"
        case isFriend = "isfriend"
        case isFamily = "isfamily"
    }
}



// MARK: error response
struct FlickrErrorResponse: Codable {
    
    let stat: String
    let code: Int
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case stat
        case code
        case message
    }
}

extension FlickrErrorResponse: LocalizedError {
    var errorDescription: String? {
        return message
    }
}
