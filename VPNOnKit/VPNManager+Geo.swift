//
//  VPNManager+Geo.swift
//  VPNOn
//
//  Created by Lex on 2/25/15.
//  Copyright (c) 2015 LexTang.com. All rights reserved.
//

import Foundation

public struct GeoIP {
    public var countryCode: String
    public var isp: String
    public var latitude: Float
    public var longitude: Float
}

extension VPNManager
{
    public func geoInfoOfIP(IP: String) -> GeoIP? {
        let URLString = String(format: "http://www.telize.com/geoip/%@", IP)
        guard let URL = NSURL(string: URLString) else { return nil }
        let request = NSMutableURLRequest(URL: URL)
        var agent = "VPN On"
        if let version = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String? {
            agent = "\(agent) \(version)"
        }
        request.HTTPShouldHandleCookies = false
        request.HTTPShouldUsePipelining = true
        request.cachePolicy = NSURLRequestCachePolicy.ReloadRevalidatingCacheData
        request.addValue(agent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        var response: NSURLResponse? = nil
        guard let data = try? NSURLConnection.sendSynchronousRequest(request, returningResponse: &response) else { return nil }
        guard let json = try? NSJSONSerialization.JSONObjectWithData(data, options: []) else { return nil }
        guard let js = json as? NSDictionary else { return nil }
        let countryCode = js.valueForKey("country_code") as! String?
        let isp = js.valueForKey("isp") as! String?
        let latitude = js.valueForKey("latitude") as! Float?
        let longitude = js.valueForKey("longitude") as! Float?
        if countryCode != nil && isp != nil && latitude != nil && longitude != nil {
            let geoIP = GeoIP(
                countryCode: countryCode!.lowercaseString,
                isp: isp!,
                latitude: latitude!,
                longitude: longitude!)
            return geoIP
        }
        
        return nil
    }
    
    // See http://stackoverflow.com/questions/25890533/how-can-i-get-a-real-ip-address-from-dns-query-in-swift
    public func IPOfHost(host: String) -> String? {
        let host = CFHostCreateWithName(nil, host).takeRetainedValue()
        CFHostStartInfoResolution(host, .Addresses, nil)
        var success: DarwinBoolean = DarwinBoolean(false)
        if let addressing = CFHostGetAddressing(host, &success) {
            let addresses = addressing.takeUnretainedValue() as NSArray
            if addresses.count > 0 {
                let theAddress = addresses[0] as! NSData
                var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                if getnameinfo(UnsafePointer(theAddress.bytes), socklen_t(theAddress.length),
                    &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        if let numAddress = String.fromCString(hostname) {
                            return numAddress
                        }
                }
            }
        }
        
        return nil
    }
    
    public func geoInfoOfHost(host: String, callback: (geoInfo: GeoIP) -> ()) -> Void {
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            [weak self] in
            if let ip = self?.IPOfHost(host), geo = self?.geoInfoOfIP(ip) {
                dispatch_async(dispatch_get_main_queue()) {
                    callback(geoInfo: geo)
                }
            }
        }
    }
}
