//
//  ViewController.swift
//  Debriefing
//
//  Created by Kohei Kajimoto on 2017/04/22.
//  Copyright © 2017 koheik.com. All rights reserved.
//

import Cocoa
import MapKit
import Charts
import AVKit
import AVFoundation

class ViewController: NSViewController {
    
    @IBOutlet weak var lineChartView: LineChartView!
    
    var mapWindowController : NSWindowController!
    var consoleWindowController : NSWindowController!
    
    var tMin : Double = Double.greatestFiniteMagnitude
    var tMax : Double = -Double.greatestFiniteMagnitude
    
    var tracks : [DebTrack] = []
    
    @IBOutlet weak var timeSlider: NSSlider!
    @IBOutlet weak var headingSlider: NSSlider!
    var heading :Double = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        if let window = self.view.window {
            if let screen = window.screen {
                let vf = screen.visibleFrame
                NSLog("Screen Rect \(vf.minX) \(vf.minY) \(vf.maxX) \(vf.maxY)")
                let height = vf.maxY - vf.minY - 0.45 * vf.height
                let y = vf.maxY - height
//                window.setFrameOrigin(NSPoint(x: vf, y: y))            }
                window.setFrame(NSRect(x: vf.minX, y: y, width: vf.width, height: height), display: true)
            }
        }
        self.createChart()
        self.createMap()
        self.createConsole()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func log(msg: String) {
        let console = self.consoleWindowController.window?.contentViewController as! ConsolerViewController
        let attr = NSAttributedString(string: (msg + "\n"), attributes: [NSFontAttributeName: NSFont(name: "Monaco", size: 12.0)!])
        console.textView.textStorage?.append(attr)
        let range = NSMakeRange(-1, 0)
        console.textView.scrollRangeToVisible(range)
    }
    
    func createChart() {
        let chartData = LineChartData()
        self.lineChartView.data = chartData
        self.lineChartView.gridBackgroundColor = NSUIColor.white
        self.lineChartView.chartDescription?.text = ""
        self.lineChartView.scaleXEnabled = true
        self.lineChartView.scaleYEnabled = false
        
        var yAxis = self.lineChartView.leftAxis
        yAxis.setLabelCount(32, force: true)
        yAxis.drawGridLinesEnabled = true
        
        yAxis = self.lineChartView.rightAxis
        //        yAxis.setLabelCount(32, force: true)
        yAxis.drawGridLinesEnabled = false
    
    }
    
    func addTrackToChart(track: DebTrack) {
        if let chartData = self.lineChartView.data {
        
            let ds1 = LineChartDataSet(values: track.d1, label: "Velocity [\(track.number)]")
            ds1.circleRadius = 0.2
            
            let ds2 = LineChartDataSet(values: track.d2, label: "Heading [\(track.number)]")
            ds2.circleRadius = 0.2
            
            let ds3 = LineChartDataSet(values: track.d3, label: "VMG [\(track.number)]")
            ds3.circleRadius = 0.2

            switch (track.number) {
            case 1:
                ds1.colors = [NSColor(red: (0xb3 / 255.0), green: (0x00 / 255.0), blue: (0x00 / 255.0), alpha: 1.0)]
                ds2.colors = [NSColor(red: (0x08 / 255.0), green: (0x68 / 255.0), blue: (0xac / 255.0), alpha: 1.0)]
                ds3.colors = [NSColor(red: (0x00 / 255.0), green: (0x68 / 255.0), blue: (0x37 / 255.0), alpha: 1.0)]
            case 2:
                ds1.colors = [NSColor(red: (0xe3 / 255.0), green: (0x4a / 255.0), blue: (0x33 / 255.0), alpha: 1.0)]
                ds2.colors = [NSColor(red: (0x43 / 255.0), green: (0xa2 / 255.0), blue: (0xca / 255.0), alpha: 1.0)]
                ds3.colors = [NSColor(red: (0x31 / 255.0), green: (0xa3 / 255.0), blue: (0x54 / 255.0), alpha: 1.0)]
            case 3:
                ds1.colors = [NSColor(red: (0xfc / 255.0), green: (0x8d / 255.0), blue: (0x59 / 255.0), alpha: 1.0)]
                ds2.colors = [NSColor(red: (0x7b / 255.0), green: (0xcc / 255.0), blue: (0xc4 / 255.0), alpha: 1.0)]
                ds3.colors = [NSColor(red: (0x78 / 255.0), green: (0xc6 / 255.0), blue: (0x79 / 255.0), alpha: 1.0)]
            case 4:
                ds1.colors = [NSColor(red: (0xfd / 255.0), green: (0xbb / 255.0), blue: (0x84 / 255.0), alpha: 1.0)]
                ds2.colors = [NSColor(red: (0xa8 / 255.0), green: (0xdd / 255.0), blue: (0xb5 / 255.0), alpha: 1.0)]
                ds3.colors = [NSColor(red: (0xad / 255.0), green: (0xdd / 255.0), blue: (0x8e / 255.0), alpha: 1.0)]
            case 5:
                ds1.colors = [NSColor(red: (0xfd / 255.0), green: (0xd4 / 255.0), blue: (0x9e / 255.0), alpha: 1.0)]
                ds2.colors = [NSColor(red: (0xcc / 255.0), green: (0xeb / 255.0), blue: (0xc5 / 255.0), alpha: 1.0)]
                ds3.colors = [NSColor(red: (0xd9 / 255.0), green: (0xf0 / 255.0), blue: (0xa3 / 255.0), alpha: 1.0)]
            default:
                ds1.colors = [NSUIColor.red]
                ds2.colors = [NSUIColor.blue]
                ds3.colors = [NSUIColor.green]
            }
            chartData.addDataSet(ds1)
            chartData.addDataSet(ds2)
            chartData.addDataSet(ds3)

            chartData.notifyDataChanged()
            self.lineChartView.notifyDataSetChanged()
        }
    }
    
    func createMap() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        self.mapWindowController = storyboard.instantiateController(withIdentifier: "MapWindowController") as! NSWindowController
        if let mapWindow = mapWindowController.window {
            if let mainWindow = self.view.window {
                let f = mainWindow.frame
                if let screen = mainWindow.screen {
                    let vf = screen.visibleFrame
                    let height = f.minY - vf.minY
                    mapWindow.setFrame(NSRect(x: mainWindow.frame.minX, y: vf.minY, width: height, height: height), display: true)
                }
            }
        }
        self.mapWindowController.showWindow(self)
    }
    
    func createConsole() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        self.consoleWindowController = storyboard.instantiateController(withIdentifier: "ConsoleWindowController") as! NSWindowController
        self.consoleWindowController.showWindow(self)
    }
    
    @IBAction func load(_ sender: Any) {
        
        let fileDialog : NSOpenPanel = NSOpenPanel()
        fileDialog.title = "Open track file..."
        fileDialog.allowedFileTypes = ["record", "gpx", "vcc"]
        
        var path = ""
        if (fileDialog.runModal() == NSModalResponseOK) {
            let chosenfile = fileDialog.url
            if (chosenfile != nil) {
                path = chosenfile!.path
            }
        } else {
            return
        }
        
        let track = DebTrack()
        track.load(path: path, number: (self.tracks.count + 1), sender: self)
    }

    func resetVmg(wind :Double) {
        self.heading = wind
        for track in self.tracks {
            for i in 0..<track.d1.count {
                let v = track.d1[i].y
                let h = 10.0 * track.d2[i].y
                track.d3[i].y = v * cos((h - wind).degToRad)
            }
            
            if let chartData = self.lineChartView.data {
                if let ds = chartData.getDataSetByIndex(3 * track.number - 1) {
                    ds.clear()
                    for entry in track.d3 {
                        let _ = ds.addEntry(entry)
                    }
                    chartData.notifyDataChanged()
                }
            }
        }
        self.lineChartView.notifyDataSetChanged()
    }
    
    @IBAction func analyze(_ sender: Any) {
        let r1 = Double(self.lineChartView.selectionLeftX)
        let r2 = Double(self.lineChartView.selectionRightX)
        let t1 = r1 * (self.tMax - self.tMin) + self.tMin
        let t2 = r2 * (self.tMax - self.tMin) + self.tMin
        let dt = t2 - t1
        let fDt = String(format: "%.2f", dt)
        if (t2 > t1) {
            let heading = self.heading
            self.log(msg: "==== Analysis ====")
            self.log(msg: "Start Time     : \(t1)")
            self.log(msg: "End Time       : \(t2)")
            self.log(msg: "Duration       : \(fDt) sec")
            self.log(msg: "Wind Direction : \(heading)")
            var i = 1
            for track in self.tracks {
                var c = 0
                var velAvg = 0.0
                var hedAvg = 0.0
                var vmgAvg = 0.0
                var j_start = -1;
                var j_end = -1;
                for j in 0..<track.d1.count {
                    let t = track.d1[j].x
                    if (t > t1 && t < t2) {
                        if (j_start == -1) {
                            j_start = j
                        }
                        j_end = j
                        velAvg += track.d1[j].y
                        hedAvg += track.d2[j].y * 10.0
                        vmgAvg += track.d3[j].y
                        c += 1
                    }
                }
                if (c > 0) {
                    velAvg /= Double(c)
                    hedAvg /= Double(c)
                    vmgAvg /= Double(c)
                }
                NSLog("selection (%d, %d)", j_start, j_end)
                
                var tckAvg = hedAvg - heading
                if (tckAvg > 90 && tckAvg <= 180) {
                    tckAvg = 180 - tckAvg
                }
                if (tckAvg > 180 && tckAvg <= 270) {
                    tckAvg = tckAvg - 180
                }
                if (tckAvg > 270) {
                    tckAvg = 360 - tckAvg
                }
                
                let fVelAvg = String(format: "%0.2f", velAvg)
                let fHedAvg = String(format: "%0.2f", hedAvg)
                let fTckAvg = String(format: "%0.2f", tckAvg)
                let fVmgAvg = String(format: "%0.4f", vmgAvg)

                self.log(msg: "Track [\(i)]")
                self.log(msg: "  Velocity Average : \(fVelAvg) knots")
                self.log(msg: "  VMG Average      : \(fVmgAvg) knots")
                self.log(msg: "  Heading Average  : \(fHedAvg) degree")
                self.log(msg: "  Tacking Average  : \(fTckAvg) degree")
                i += 1
            }
        }
    }
    
    @IBAction func setTime(_ sender: Any) {
        if (sender is NSSlider) {
            let slider = sender as! NSSlider
            let r = slider.doubleValue / 100.0
            let visible = (self.lineChartView.highestVisibleX - self.lineChartView.lowestVisibleX)
            let t = r * visible + self.lineChartView.lowestVisibleX

            if (self.mapWindowController != nil) {
                let viewController = self.mapWindowController.window?.contentViewController as! MapViewController
                viewController.setTime(t)
            }
            
            for track in self.tracks {
                track.seekTo(at: t)
            }
        }
    }
    
    @IBAction func setWindDirection(_ sender: Any) {
        if (sender is NSSlider) {
            let slider = sender as! NSSlider
            let h = slider.doubleValue
            self.setWindDirection(wind: h)
        }
    }
    
    func setWindDirection(wind: Double) {
        self.resetVmg(wind: wind)
        let viewController = self.mapWindowController.window?.contentViewController as! MapViewController
        let mapView = viewController.map!
        let camera = mapView.camera
        camera.heading = wind
        mapView.setCamera(camera, animated: true)
    }
}

