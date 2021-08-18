//
//  FlickrClient.swift
//  VT_final
//
//  Created by Andi Xu on 8/17/21.
//

import Foundation


class FlickrClient {
    
    static let apiKey = "732571de892a765ad48e2c66577216d4"
    static let apiSecret = "8bec2f4139f78e9a"
    
    
    enum Endpoints {
        static let base = "https://www.flickr.com/services/rest/?method=flickr.photos.search"
        static let apiKeyParam = "&api_key=\(apiKey)"
        
        static let bboxQuery = "&bbox=-5%2C-5%2C5%2C5"
        static let contentTypeQuery = "&content_type=1"
        static let flickrQuery = Endpoints.bboxQuery + Endpoints.contentTypeQuery
        
        case search(Double,Double)
        case photoPath(Int, String, String, String)
        
        var stringValue: String {
            switch self {
            case .search(let lat, let long):
                return Endpoints.base + Endpoints.apiKeyParam + Endpoints.flickrQuery + "&lat=\(lat)&lon=\(long)&page=1&per_page=100&format=json&nojsoncallback=1"
            case .photoPath(let farm, let server, let id, let secret):
                return "https://farm\(farm).static.flickr.com/\(server)/\(id)_\(secret).jpg"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    
    class func taskForGetRequest<ResponseType: Decodable>(url: URL, responseType: ResponseType.Type, completion: @escaping (ResponseType?, Error?) -> Void) {
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            print("Got to taskForGetRequest task")

            guard let data = data else {
                print ("no data in this request")
                DispatchQueue.main.async {
                  completion(nil, error)
                }
                return
            }
            let newData = data
            let decoder = JSONDecoder()
            print(String(data: newData, encoding: .utf8)!)
            
            do {
                let responseObject = try decoder.decode(ResponseType.self, from: newData)
                DispatchQueue.main.async {
                    completion(responseObject, nil)
                }
            } catch {
                print(error.localizedDescription )
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        task.resume()
    }
    
    
    class func search(lat: Double, long: Double, completion: @escaping ([FlickrPhoto], Error?) -> Void) -> Void {
        print("were in search func")
      //  print("url: \(Endpoints.search(lat,long).url)")
        let _ = taskForGetRequest(url: Endpoints.search(lat,long).url, responseType: FlickrResponse.self) { (response, error) in
            if let response = response {
                print("there's been a response under search")
                completion(response.photos.photo, nil)
            } else {
                print("search error: \(error?.localizedDescription)")
                completion([], error)
            }
        }
    }
    
    
    /// construct the url of this photo from FlickrPhoto
    class func photoPathURL(photo: FlickrPhoto) -> URL {
        let url=Endpoints.photoPath(photo.farm, photo.server, photo.id, photo.secret).url
        print (url)
        return url
    }
    
    /// download the image according to url
    class func downloadPosterImage(photoURL: URL, completion: @escaping (Data?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: photoURL) { data, response, error in
            DispatchQueue.main.async {
                completion(data, error)
            }
        }
        task.resume()
    }
}
