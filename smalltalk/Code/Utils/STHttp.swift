//
//  SMHttp.swift
//  smalltalk
//
//  Created by Mikko Hämäläinen on 23/09/15.
//  Copyright (c) 2015 Mikko Hämäläinen. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import SDWebImage
import SwiftyJSON

struct STHttp {
	static func get(url: String, auth: (String, String)? = nil) -> SignalProducer<Result<Any, NSError>, NSError> {
		NSLog("STHttp.get [%@]", url)
		let urlRequest = STHttp.urlRequest(url, contentType: "application/json", auth: auth)
		urlRequest.HTTPMethod = "GET"
		return STHttp.doRequest(urlRequest)
	}
	
	static func post(url: String, data: [NSObject: AnyObject], auth: (String, String)? = nil) -> SignalProducer<Result<Any, NSError>, NSError> {
		NSLog("STHttp.post [%@] data %@", url, data)
		let urlRequest = STHttp.urlRequest(url, contentType: "application/json", auth: auth)
		urlRequest.HTTPMethod = "POST"
		do {
			let theJSONData =  try NSJSONSerialization.dataWithJSONObject(data, options: NSJSONWritingOptions(rawValue: 0))
			urlRequest.HTTPBody = theJSONData
			return STHttp.doRequest(urlRequest)
		} catch {
			assert(false, "SJSONSerialization.dataWithJSONObject failed e")
			return SignalProducer<Result<Any, NSError>, NSError>.empty //TODO! Return an error!
		}
	}
	
	static func getFromS3(bucket: String, key: String) -> SignalProducer<Result<(UIImage, String), NSError>, NSError> {
		return signGetIfNotInCache(bucket, key: key)
			.flatMap(FlattenStrategy.Merge, transform: {
				url in
				return STHttp.doImageGet(url).observeOn(QueueScheduler()).retryWithDelay(15, interval: 5, onScheduler: QueueScheduler())
			})
			.retry(2)
	}
	
	static func getImage(url: String) -> SignalProducer<Result<(UIImage, String), NSError>, NSError> {
		if url == "" {
			return SignalProducer(error: NSError(domain: "smalltalk.getimage", code: -1, userInfo: [ NSLocalizedDescriptionKey: "empty url"]))
		}
		
		return STHttp.doImageGet(url).observeOn(QueueScheduler()).retryWithDelay(15, interval: 5, onScheduler: QueueScheduler())
	}
	
	static func getFromCache(bucket: String, key: String) -> UIImage? {
		let url = self.cacheKey(self.urlWithoutSigning(bucket, key:key))
		return SDImageCache.sharedImageCache().imageFromDiskCacheForKey(url)
	}
	
	static func putToS3(bucket: String, key: String, image: UIImage) -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.sign("PUT", bucket: bucket, key: key)
			.flatMap(FlattenStrategy.Merge, transform: {
				(url: String) -> SignalProducer<Result<Any, NSError>, NSError> in
				let urlRequest = STHttp.urlRequest(url, contentType: nil, auth: nil)
				urlRequest.HTTPMethod = "PUT"
				urlRequest.HTTPBody = UIImageJPEGRepresentation(image, 0.75)
				return STHttp.doRequest(urlRequest)
					.on {
						_ in
						//Cache the uploaded image
						let url = NSURL(string: url)
						SDImageCache.sharedImageCache().storeImage(image, forKey: self.cacheKey(url!))
				}
			})
			.retry(2)
	}
	
	//Private methods
	static private func signGetIfNotInCache(bucket: String, key: String) -> SignalProducer<String, NSError>  {
		//If image is already in cache, there is no need to sign - we'll just pass through the cache key for doS3Get which will fetch it form cache
		let url = urlWithoutSigning(bucket, key: key)
		let cachedUrl = self.cacheKey(url)
		let imageInCache = SDImageCache.sharedImageCache().diskImageExistsWithKey(cachedUrl)
		if (imageInCache) {
			return SignalProducer(values: [cachedUrl])
		}
		
		//Not in cache, sign to get the actual s3 url
		return STHttp.sign("GET", bucket: bucket, key: key)
	}
	
	static private func urlWithoutSigning(bucket: String, key: String) -> NSURL {
		return NSURL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
	}
	
	static private func AWSUrl(bucket: String, key: String) -> NSURL {
		return NSURL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
	}
	
	//Do AWS signing
	static private func sign(method: String, bucket: String, key: String) -> SignalProducer<String, NSError> {
		let data = [
			"method": method,
			"bucket": bucket,
			"key": key
		]
		return STHttp.post("\(Configuration.mainApi)/sign/new", data: data, auth:(User.username, User.token))
		.map {
			//Grab the fetched url
			(result: Result<Any, NSError>) -> String in
			if (result.value != nil) {
				let dict = result.value as! JSON
				return dict["url"].stringValue
			}
			
			return "no-url"
		}
	}
	
	static private func cacheKey(url: NSURL) -> String {
		//Url without query parameters (since they keep changing for every query)
		let newUrl = NSURL(scheme: url.scheme, host: url.host!, path: url.path!)
		return newUrl!.absoluteString
	}
	
	static private func doImageGet(strUrl: String) -> SignalProducer<Result<(UIImage, String), NSError>, NSError> {
		NSLog("doImageGet [%@]", strUrl)
		let url: NSURL = NSURL(string: strUrl)!
		let cachedUrl = self.cacheKey(url)
		let imageInCache = SDImageCache.sharedImageCache().diskImageExistsWithKey(cachedUrl)
		if (imageInCache) {
			let image = SDImageCache.sharedImageCache().imageFromDiskCacheForKey(strUrl)
			let retResult = Result<(UIImage, String), NSError>(value: (image, strUrl))

			return SignalProducer(values: [retResult])
		}
		
		let urlRequest = STHttp.urlRequest(strUrl, contentType: nil, auth: nil)
		urlRequest.HTTPMethod = "GET"
		return STHttp.doRequest(urlRequest, deserializeJSON: false).map {
			result in
			if result.value != nil {
				let data = result.value as! NSData
				let image = UIImage(data: data)!
				
				SDImageCache.sharedImageCache().storeImage(image, forKey: self.cacheKey(url))
				let retResult = Result<(UIImage, String), NSError>(value: (image, strUrl))
				return retResult
			}
			
			return Result<(UIImage, String), NSError>(error: result.error!)
		}
	}
	
	static private func urlRequest(url: String, contentType: String?, auth: (String, String)?) -> NSMutableURLRequest {
		let urlRequest = NSMutableURLRequest(URL: NSURL(string: url)!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        if contentType != nil {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
		if auth != nil {
			let (username, password) = auth!
			let loginString = "\(username):\(password)"
			let loginData: NSData = loginString.dataUsingEncoding(NSUTF8StringEncoding)!
			let base64LoginString = loginData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
			
			urlRequest.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
		}
		return urlRequest
	}
	
	static private func doRequest(urlRequest: NSURLRequest, deserializeJSON: Bool = true) -> SignalProducer<Result<Any, NSError>, NSError> {
		return STHttp.networkProducer(urlRequest)
			.flatMap(FlattenStrategy.Merge, transform: {
				(incomingData: NSData, response: NSURLResponse) in
				return SignalProducer<(NSData, NSURLResponse), NSError> { observer, disposable in
					//NSLog("Response %@ %@", response, NSThread.isMainThread())
					let statusCode = (response as! NSHTTPURLResponse).statusCode
					if  statusCode >= 200 && statusCode < 299 {
						observer.sendNext((incomingData, response))
					} else {
						var errorSent = false
						if incomingData.length > 0 {
							if deserializeJSON {
								do {
									let json = try NSJSONSerialization.JSONObjectWithData(incomingData, options: NSJSONReadingOptions(rawValue: 0))
									observer.sendFailed(
											NSError(domain: "smalltalk.http",
												code: statusCode,
												userInfo: [ NSLocalizedDescriptionKey: "\(NSHTTPURLResponse.localizedStringForStatusCode(statusCode)) + \(json)"]
										)
									)
									errorSent = true
								} catch {}
							}
						}
						if !errorSent {
							//If no incomingData was sent in error
							observer.sendFailed(
								NSError(domain: "smalltalk.http",
									code: statusCode,
									userInfo: [ NSLocalizedDescriptionKey: "\(NSHTTPURLResponse.localizedStringForStatusCode(statusCode))"]
								)
							)
						}
					}
					
					observer.sendCompleted()
				}
			})
			.map {
				(incomingData: NSData, response: NSURLResponse) -> Result<Any, NSError> in
				if incomingData.length > 0 {
					if deserializeJSON {
						let json = JSON(data: incomingData)
						return Result.Success(json) //Result<JSON, NSError>(value: json)
					} else {
						return Result.Success(incomingData)
					}
				}
				
				return Result.Success("")
		}
	}
	
	static func networkProducer(urlRequest: NSURLRequest) -> SignalProducer<(NSData, NSURLResponse), NSError>
	{
		return NSURLSession.sharedSession().rac_dataWithRequestBackgroundSupport(urlRequest)
			.retry(2)
	}
}

