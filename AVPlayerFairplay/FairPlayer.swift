//
//  FairPlayer.swift
//  AVPlayerFairplay
//
//  Created by Meidiana Monica on 13/11/20.
//  Copyright © 2020 Meidiana Monica. All rights reserved.
//

import Foundation
import AVFoundation

class FairPlayer: AVPlayer {
    private let queue = DispatchQueue(label: "com.icapps.fairplay.queue")
    
    func play(asset: AVURLAsset) {
        // Set the resource loader delegate to this class. The `resourceLoader`'s delegate will be
        // triggered when FairPlay handling is required.
        asset.resourceLoader.setDelegate(self, queue: queue)
        
        // Load the asset in the player.
        let item = AVPlayerItem(asset: asset)
        
        // Set the current item in this player instance.
        replaceCurrentItem(with: item)
        
        // Start playing the item. From the moment the `play` is triggered the `resourceLoader` will
        // do the rest of the work.
        play()
    }
    
}

extension FairPlayer: AVAssetResourceLoaderDelegate {
  
  func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
    // We first check if a url is set in the manifest.
    guard let url = loadingRequest.request.url else {
      print("🔑", #function, "Unable to read the url/host data.")
      loadingRequest.finishLoading(with: NSError(domain: "com.icapps.error", code: -1, userInfo: nil))
      return false
    }
    print("🔑", #function, url)
        
    // When the url is correctly found we try to load the certificate date. Watch out! For this
    // example the certificate resides inside the bundle. But it should be preferably fetched from
    // the server.
      guard
        let certificateURL = Bundle.main.url(forResource: "certificate", withExtension: "der"),
        let certificateData = try? Data(contentsOf: certificateURL) else {
        print("🔑", #function, "Unable to read the certificate data.")
        loadingRequest.finishLoading(with: NSError(domain: "com.icapps.error", code: -2, userInfo: nil))
        return false
      }

      // Request the Server Playback Context.
      let contentId = "hls.icapps.com"
      guard
          let contentIdData = contentId.data(using: String.Encoding.utf8),
          let spcData = try? loadingRequest.streamingContentKeyRequestData(forApp: certificateData, contentIdentifier: contentIdData, options: nil),
          let dataRequest = loadingRequest.dataRequest else {
          loadingRequest.finishLoading(with: NSError(domain: "com.icapps.error", code: -3, userInfo: nil))
          print("🔑", #function, "Unable to read the SPC data.")
          return false
      }

      // Request the Content Key Context from the Key Server Module.
      let ckcURL = URL(string: "https://hls.icapps.com/ckc")!
      var request = URLRequest(url: ckcURL)
      request.httpMethod = "POST"
      request.httpBody = spcData
      let session = URLSession(configuration: URLSessionConfiguration.default)
      let task = session.dataTask(with: request) { data, response, error in
        if let data = data {
          // The CKC is correctly returned and is now send to the `AVPlayer` instance so we
          // can continue to play the stream.
          dataRequest.respond(with: data)
          loadingRequest.finishLoading()
        } else {
          print("🔑", #function, "Unable to fetch the CKC.")
          loadingRequest.finishLoading(with: NSError(domain: "com.icapps.error", code: -4, userInfo: nil))
        }
      }
      task.resume()

      return true
    }
  
}
