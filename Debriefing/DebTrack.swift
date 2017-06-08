//
//  DebTrack.swift
//  Debriefing
//
//  Created by Kohei Kajimoto on 2017/04/22.
//  Copyright © 2017 koheik.com. All rights reserved.
//

import Foundation
import MapKit
import AVKit
import AVFoundation

import Charts

extension Double {
    var degToRad: Double { return self * .pi / 180.0 }
    var radToDeg: Double { return self * 180.0 / .pi }
    var mpsToKnt: Double { return self * 3600.0 / 1852.0 }
}

class DebVideo {
    var start: Int64
    var file: URL
    var asset : AVAsset
    
    init (start: Int64, file: URL) {
        self.start = start
        self.file = file
        self.asset = AVAsset(url: file)
    }
}

class DebTrack {
    
    var d1 =  [ChartDataEntry] ()
    var d2 =  [ChartDataEntry] ()
    var d3 =  [ChartDataEntry] ()
    var mapData : [CLLocation] = []
    var videos : [DebVideo] = []
    
    var tMin : Double = Double.greatestFiniteMagnitude
    var tMax : Double = -Double.greatestFiniteMagnitude
    
    var latMin = Double.greatestFiniteMagnitude
    var latMax = -Double.greatestFiniteMagnitude
    
    var lonMin = Double.greatestFiniteMagnitude
    var lonMax = -Double.greatestFiniteMagnitude
    
    var tOffset :Double = 0
    
    var path :String
    var number :Int
    
    var mixComposition :AVMutableComposition?
    var playerItem :AVPlayerItem?
    var player :AVPlayer!
    var monitorController :NSWindowController?
    
    var center : CLLocationCoordinate2D!
    var span : MKCoordinateSpan!
    
    var parsing : Bool = false

    init () {
        self.path = ""
        self.number = 0
    }
    
    func load(path :String, number :Int, sender :ViewController) {
        self.path = path
        self.number = number
        
        var loaded = false
        
        let url = NSURL(fileURLWithPath: path)
        let ext = url.pathExtension
        if (ext == "record") {
            // tray gps metadata first
            let gpsmeta = url.deletingPathExtension!.path + ".gpsmeta"
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: gpsmeta)
                let dict = attr as NSDictionary
                if (dict.fileSize() > 0) {
                    loadGpsmeta(path: gpsmeta, sender: sender)
                    loaded = true
                }
            } catch { }

            // then record
            if (loaded == false) {
                do {
                    let attr = try FileManager.default.attributesOfItem(atPath: path)
                    let dict = attr as NSDictionary
                    if (dict.fileSize() > 0) {
                        loadRecord(path: path)
                        loaded = true
                    }
                } catch { }
            }
            
            let camera = NSURL(fileURLWithPath: path).deletingPathExtension!.path + ".camera"
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: camera)
                let dict = attr as NSDictionary
                if (dict.fileSize() > 0) {
                    loadCamera(path: camera)
                }
            } catch { }

            self.monitorController?.showWindow(sender)
            
            if (self.tMin < sender.tMin) {
                sender.tMin = self.tMin
            }
            if (self.tMax > sender.tMax) {
                sender.tMax = self.tMax
            }
            
            sender.tracks.append(self)
            sender.addTrackToChart(track: self)
            
            let mapViewController = sender.mapWindowController.window?.contentViewController as! MapViewController
            mapViewController.addTrack(track: self)

        } else if (ext == "gpx") {
            loadGpx(path: path, sender: sender)
        } else if (ext == "vcc") {
            loadVcc(path: path, sender: sender)
        }
    }
    
    func loadRecord(path: String) {
        var data : String!
        do {
            data = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            print(error)
            return
        }
        
        let lines = data.components(separatedBy: .newlines)
        var t_prev : Double = 0.0
        var rlon_prev : Double = 0.0
        var rlat_prev : Double = 0.0
        let r : Double = 6378137.0
        for line in lines {
            let tokens = line.components(separatedBy: ",")
            if (tokens.count < 5) {
                continue
            }
            let t : Double = Double(tokens[1])!
            let lat : Double = Double(tokens[2])!
            let lon : Double = Double(tokens[3])!
            let v : Double = Double(tokens[4])!
            
            if (t < self.tMin) {
                self.tMin = t
            }
            if (t > self.tMax) {
                self.tMax = t
            }
            
            let rlon : Double = lon.degToRad
            let rlat : Double = lat.degToRad
            if (t_prev == 0.0) {
                rlon_prev = rlon
                rlat_prev = rlat
            }

            let ddx = r * cos(rlat) * (rlon - rlon_prev)
            let ddy = r * (rlat - rlat_prev)
            var h : Double = 0.0
            if (ddx > 0.0) {
                h = acos( ddy / sqrt(ddx * ddx + ddy * ddy) ).radToDeg
            }
            if (ddx < 0.0) {
                h = 360.0 - acos( ddy / sqrt(ddx * ddx + ddy * ddy) ).radToDeg
            }
            
            t_prev = t
            rlat_prev = rlat
            rlon_prev = rlon
            
            self.d1.append(ChartDataEntry(x: t, y: v))
            self.d2.append(ChartDataEntry(x: t, y: h / 10.0))
            
            if (self.latMin > lat) {
                self.latMin = lat
            }
            if (self.latMax < lat) {
                self.latMax = lat
            }
            if (self.lonMin > lon) {
                self.lonMin = lon
            }
            if (self.lonMax < lon) {
                self.lonMax = lon
            }
            self.mapData.append(CLLocation(latitude: lat, longitude: lon))
        }
        
        self.tOffset = 0
        
        self.center = CLLocationCoordinate2DMake((self.latMin + self.latMax) / 2.0, (self.lonMin + self.lonMax) / 2.0)
        self.span = MKCoordinateSpanMake((self.latMax - self.latMin), (self.lonMax - self.lonMin))
        
        let wind = 195.0;
        
        for i in 0..<self.d1.count {
            let t = self.d1[i].x
            let v = self.d1[i].y
            let h = 10.0 * self.d2[i].y
            self.d3.append(ChartDataEntry(x: t, y: v * cos((h - wind).degToRad)))
        }
    }

    func loadGpsmeta(path :String, sender :ViewController) {
        var offset = 0.0
        var prev_t = -1.0;
        var data : String!
        do {
            data = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            print(error)
            return
        }
        
        let lines = data.components(separatedBy: .newlines)
        for line in lines {
            let tokens = line.components(separatedBy: ",")
            if (tokens.count < 7) {
                continue
            }
            let t : Double = Double(tokens[1])!
            let utc : Double = Double(tokens[2])!
            let lat : Double = Double(tokens[3])!
            let lon : Double = Double(tokens[4])!
            let v : Double = Double(tokens[5])!
            let h : Double = Double(tokens[6])!
            
            if (t < self.tMin) {
                self.tMin = t
            }
            if (t > self.tMax) {
                self.tMax = t
            }
            
            if (t - prev_t < 0.5) {
                continue;
            } else {
                prev_t = t
            }
            
            offset += (utc - t)
            
            self.d1.append(ChartDataEntry(x: t, y: v))
            self.d2.append(ChartDataEntry(x: t, y: h / 10.0))
            
            if (self.latMin > lat) {
                self.latMin = lat
            }
            if (self.latMax < lat) {
                self.latMax = lat
            }
            if (self.lonMin > lon) {
                self.lonMin = lon
            }
            if (self.lonMax < lon) {
                self.lonMax = lon
            }
            self.mapData.append(CLLocation(latitude: lat, longitude: lon))
        }
        
        // convert to utc
        offset /= Double(self.d1.count)
        for i in 0..<self.d1.count {
            self.d1[i].x += offset
            self.d2[i].x += offset
        }
        self.tMin += offset
        self.tMax += offset
        self.tOffset = offset
        
        self.center = CLLocationCoordinate2DMake((self.latMin + self.latMax) / 2.0, (self.lonMin + self.lonMax) / 2.0)
        self.span = MKCoordinateSpanMake((self.latMax - self.latMin), (self.lonMax - self.lonMin))
        
        for i in 0..<self.d1.count {
            let t = self.d1[i].x
            let v = self.d1[i].y
            let h = 10.0 * self.d2[i].y
            self.d3.append(ChartDataEntry(x: t, y: v * cos((h - sender.heading).radToDeg)))
        }
    }
    
    func loadCamera(path: String) {
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            for line in lines {
                let tokens = line.components(separatedBy: ",")
                if (tokens.count < 7) {
                    continue
                }
                let t : Double = Double(tokens[1])!
                let start = Int64(t * 1000)
                let f : String = tokens[2]
                let e : String = tokens[3]
                if (e == "VIDEO_START" || e == "VIDEO_SPLIT") {
                    self.videos.append(DebVideo(start: start, file: URL(fileURLWithPath: f)))
                }
            }
        } catch {
        }
        
        // videos
        let mixComposition = AVMutableComposition()
        let track = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        for video in self.videos {
            let asset = video.asset
            do {
                try track.insertTimeRange(
                    CMTimeRangeMake(kCMTimeZero, asset.duration),
                    of: asset.tracks(withMediaType: AVMediaTypeVideo)[0],
                    at: CMTimeMake(video.start, 1000))
            } catch _ {
                print("Failed to load track")
            }
        }
        self.mixComposition = mixComposition
        
        let playerItem = AVPlayerItem(asset: mixComposition)
        self.playerItem = playerItem
        
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        
        let playerView = AVPlayerView()
        playerView.player = player
        
        //        player.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 100), queue: DispatchQueue.main) {
        //            [unowned self] time in
        //            let timeString = String(format: "%02.2f", CMTimeGetSeconds(time))
        //            print("time is \(timeString)")
        //            self.delegate?.playerPlaybackstimer(timeString)
        //            let t = CMTimeGetSeconds(time)
        //            if (self.timeSlider != nil) {
        //                self.timeSlider.doubleValue = (100 * t / 3600.0)
        //            }
        //        }
        
        let window = NSWindow(contentRect: NSMakeRect(50, 50, 480, 270),
                              styleMask: NSWindowStyleMask.titled,
                              backing: NSBackingStoreType.buffered,
                              defer: true)
        window.styleMask.insert(.resizable)
        window.title = "Monitor"
        let controller = NSWindowController(window: window)
        self.monitorController = controller
        window.contentView = playerView
    }
    
    func loadGpx(path :String, sender: ViewController) {

        self.parsing = true
        let fileData:NSData? = NSData(contentsOfFile:path)
        GPXParser.parse(fileData as Data!, completion: {(success: Bool, gpx: GPX?) -> Void in
            let track:Track = gpx!.tracks[0] as! Track

            let r : Double = 6378137.0
            
            var t_prev : Double = 0.0
            var rlon_prev : Double = 0.0
            var rlat_prev : Double = 0.0

            var i = 0
            
            for f in track.fixes {
                let fix = f as! Fix
                let lat : Double = fix.latitude
                let lon : Double = fix.longitude
                let rlat : Double = fix.latitude.degToRad
                let rlon : Double = fix.longitude.degToRad
                let t : Double = (f as! Fix).epoch
                
                NSLog("time \(t)")

                if (i == 0) {
                    rlon_prev = rlon
                    rlat_prev = rlat
                }
                if (t < self.tMin) {
                    self.tMin = t
                }
                if (t > self.tMax) {
                    self.tMax = t
                }
                if (lat < self.latMin) {
                    self.latMin = lat
                }
                if (lat > self.latMax) {
                    self.latMax = lat
                }
                if (lon < self.lonMin) {
                    self.lonMin = lon
                }
                if (lon > self.lonMax) {
                    self.lonMax = lon
                }
                
                let x1 = r * cos(rlat) * cos(rlon)
                let y1 = r * cos(rlat) * sin(rlon)
                let z1 = r * sin(rlat)
                
                let x2 = r * cos(rlat_prev) * cos(rlon_prev)
                let y2 = r * cos(rlat_prev) * sin(rlon_prev)
                let z2 = r * sin(rlat_prev)
                
                let dx = x1 - x2
                let dy = y1 - y2
                let dz = z1 - z2
                let dt = t - t_prev
                
                let v : Double = (sqrt(dx * dx + dy * dy + dz * dz) / dt).mpsToKnt
                self.d1.append(ChartDataEntry(x: t, y: v))
                
                let ddx = r * cos(rlat) * (rlon - rlon_prev)
                let ddy = r * (rlat - rlat_prev)
                var heading : Double = 0.0
                if (ddx > 0.0) {
                    heading = acos(ddy / sqrt(ddx * ddx + ddy * ddy)).radToDeg
                }
                if (ddx < 0.0) {
                    heading = 360.0 - acos(ddy / sqrt(ddx * ddx + ddy * ddy)).radToDeg
                }
                
                self.d2.append(ChartDataEntry(x: t, y: heading / 10.0))
                self.d3.append(ChartDataEntry(x: t, y: v * cos( (heading - sender.heading).degToRad) ))
                
                self.mapData.append(CLLocation(latitude: lat, longitude: lon))
                
                rlon_prev = rlon
                rlat_prev = rlat
                t_prev = t
                i += 1
            }

            self.tOffset = 0.0
            self.center = CLLocationCoordinate2DMake((self.latMin + self.latMax) / 2.0, (self.lonMin + self.lonMax) / 2.0)
            self.span = MKCoordinateSpanMake((self.latMax - self.latMin), (self.lonMax - self.lonMin))

            if (self.tMin < sender.tMin) {
                sender.tMin = self.tMin
            }
            if (self.tMax > sender.tMax) {
                sender.tMax = self.tMax
            }
            
            sender.tracks.append(self)
            sender.addTrackToChart(track: self)
            
            let mapViewController = sender.mapWindowController.window?.contentViewController as! MapViewController
            mapViewController.addTrack(track: self)
        })
    }

    func loadVcc(path :String, sender: ViewController) {
        
        self.parsing = true
        let fileData:NSData? = NSData(contentsOfFile:path)
        VCCParser.parse(fileData as Data!, completion: {(success: Bool, vcc: VCC?) -> Void in
            if let vcc = vcc {
                let track:VCCTrack = vcc.tracks[0] as! VCCTrack
                
                for f in track.trackpoints {
                    let trkpnt = f as! VCCTrackpoint
                    let lat : Double = trkpnt.latitude
                    let lon : Double = trkpnt.longitude
                    let t : Double = trkpnt.epoch
                    let v : Double = trkpnt.speed
                    let h : Double = trkpnt.heading
                    
                    if (t < self.tMin) {
                        self.tMin = t
                    }
                    if (t > self.tMax) {
                        self.tMax = t
                    }
                    if (lat < self.latMin) {
                        self.latMin = lat
                    }
                    if (lat > self.latMax) {
                        self.latMax = lat
                    }
                    if (lon < self.lonMin) {
                        self.lonMin = lon
                    }
                    if (lon > self.lonMax) {
                        self.lonMax = lon
                    }
                    
                    self.d1.append(ChartDataEntry(x: t, y: v))
                    self.d2.append(ChartDataEntry(x: t, y: h / 10.0))
                    self.d3.append(ChartDataEntry(x: t, y: v * cos((h - sender.heading).degToRad)))
                    
                    self.mapData.append(CLLocation(latitude: lat, longitude: lon))
                }
                
                self.tOffset = 0.0
                self.center = CLLocationCoordinate2DMake((self.latMin + self.latMax) / 2.0, (self.lonMin + self.lonMax) / 2.0)
                self.span = MKCoordinateSpanMake((self.latMax - self.latMin), (self.lonMax - self.lonMin))
                
                if (self.tMin < sender.tMin) {
                    sender.tMin = self.tMin
                }
                if (self.tMax > sender.tMax) {
                    sender.tMax = self.tMax
                }
                
                sender.tracks.append(self)
                sender.addTrackToChart(track: self)
                
                let mapViewController = sender.mapWindowController.window?.contentViewController as! MapViewController
                mapViewController.addTrack(track: self)
            }
        })
    }
    
    func seekTo(at : Double) {
        if let player = self.player {
            let t = at - self.tOffset
            let ct = CMTimeMake(Int64(t * 1000), 1000)
            let allow = CMTimeMake(150, 1000)
            player.seek(to: ct, toleranceBefore: allow, toleranceAfter: allow)
        }
    }

    func estimateWindDirection() -> Double {
        var sumV = 0.0
        var sumC = 0.0
        var sumS = 0.0
        for i in 0..<self.d1.count {
            let v = self.d1[i].y
            let h = 10.0 * self.d2[i].y
            let v2 = v * v
            sumV += v2
            sumC += v2 * cos(h.degToRad)
            sumS += v2 * sin(h.degToRad)
        }
        let x = sumC / sumV
        let y = sumS / sumV
        let r = 1 / sqrt(x*x + y*y)
        NSLog("x \(x)")
        NSLog("y \(y)")
        NSLog("rx \(r*x)")
        NSLog("ry \(r*y)")
        var wind = acos(r * x).radToDeg
        if (sumS < 0.0) {
            wind = 360 - wind
        }
        return wind
    }
}

