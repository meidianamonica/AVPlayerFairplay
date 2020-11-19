//
//  ViewController.swift
//  AVPlayerFairplay
//
//  Created by Meidiana Monica on 13/11/20.
//  Copyright © 2020 Meidiana Monica. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAssetResourceLoaderDelegate {

    @IBOutlet weak var videoView: UIView!
    var player: AVPlayer!
    var streamingURL: String = ""
    private let queue = DispatchQueue(label: "com.icapps.fairplay.queue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        streamingURL = "https://willzhanmswest.streaming.mediaservices.windows.net/1efbd6bb-1e66-4e53-88c3-f7e5657a9bbd/RussianWaltz.ism/manifest(format=m3u8-aapl)"
        if let url = URL(string: streamingURL) {
            //1. Create AVPlayer object
            let asset = AVURLAsset(url: url)
//            let queue = DispatchQueue(label: "LicenseGetQueue")
            asset.resourceLoader.setDelegate(self, queue: queue)
            let playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            
            //2. Create AVPlayerLayer object
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = self.videoView.bounds //bounds of the view in which AVPlayer should be displayed
            playerLayer.videoGravity = .resizeAspect
            
            //3. Add playerLayer to view's layer
            self.videoView.layer.addSublayer(playerLayer)
            
            //4. Play Video
            player.play()
            
        }
        
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        //we first check if a url is set in the manifest
        guard let url = loadingRequest.request.url else {
            print("[ViewController] resouceLoader", #function, "Unable to read the url/host data")
            loadingRequest.finishLoading(with: NSError(domain: "com.iccaps.error", code: -1, userInfo: nil))
            return false
        }
        print("[ViewController] resouceLoader URL", #function, url)
        
        //when the url is correctly found we try to load the certificate date. watch out for this
        //example the certificate resides inside the bundle. but it sould be preferable fetched from the server
        guard
            let certificateURL = Bundle.main.url(forResource: "certificate", withExtension: "der"), let certificateData = try? Data(contentsOf: certificateURL)
            else {
                print("[ViewController] resourceLoader", #function, "Unable to read the certificate data.")
                loadingRequest.finishLoading(with: NSError(domain: "com.icapps.errror", code: -2, userInfo: nil))
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

