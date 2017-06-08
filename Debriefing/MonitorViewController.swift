//
//  MonitorViewController.swift
//  Debriefing
//
//  Created by Kohei Kajimoto on 2017/04/22.
//  Copyright © 2017 koheik.com. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation

class MonitorViewController: NSViewController
{
    @IBOutlet weak var playerView: AVPlayerView!
    
    private var player : AVPlayer!
    private var layer : AVPlayerLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("MonitorViewController#viewDidLoad")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        NSLog("MonitorViewController#viewWillAppear")
    }
    
    open func setPlayer(_ player : AVPlayer) {
        NSLog("MonitorViewController#setPlayer")
        self.playerView.player = player
    }
}
