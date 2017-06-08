//
//  MapViewController.swift
//  Debriefing
//
//  Created by Kohei Kajimoto on 2017/04/22.
//  Copyright © 2017 koheik.com. All rights reserved.
//

import Foundation
import MapKit

class MapViewController: NSViewController, MKMapViewDelegate {
    @IBOutlet weak var map: MKMapView!

    private var tracks: [DebTrack] = []
    private var polylines: [MKPolyline] = []
    private var annotations : [MKPointAnnotation] = []
    
    private var time : Double = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if overlay is MKPolyline {
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = NSColor.blue
            let idx = self.polylines.index(of: overlay as! MKPolyline)
            if (idx == 1) {
//                polylineRenderer.strokeColor = NSColor.red
            }
            polylineRenderer.lineWidth = 1;
            
            return polylineRenderer
        }
        
        return MKPolylineRenderer()
    }
    
    open func addTrack(track : DebTrack) {
        let coordinate = track.mapData.map({(location: CLLocation!) -> CLLocationCoordinate2D in
            return location.coordinate
        })
        let polyline = MKPolyline(coordinates: coordinate, count: coordinate.count)
        self.tracks.append(track);
        self.polylines.append(polyline)
        self.map.add(polyline)

        if (self.tracks.count == 1) {
            let region : MKCoordinateRegion  = MKCoordinateRegionMake(track.center, track.span)
            let mapView = self.map!

            var wind :Double = track.estimateWindDirection()
            wind += 180.0
            if (wind > 360.0) {
                wind -= 360.0
            }
            NSLog("estimate wind direction=%f", wind)

            mapView.setRegion(region, animated: false)
            let camera = mapView.camera
            camera.heading = wind
            mapView.setCamera(camera, animated: true)

        }

        // create annotation
        let t = self.time
        var i = 0
        while (i < track.d1.count && track.d1[i].x < t) {
            i += 1
        }
        if (i >= track.d1.count) {
            i = track.d1.count - 1
        }
        let annotation = MKPointAnnotation()
        annotation.coordinate = track.mapData[i].coordinate
        self.map.addAnnotation(annotation)
        self.annotations.append(annotation)
    }
    
    open func setTime(_ t : Double) {
        if (abs(self.time - t) < 0.2) {
            return
        }
        self.time = t
        var j = 0
        for track in self.tracks {
            var i = 0
            while (i < track.d1.count && track.d1[i].x < t) {
                i += 1
            }
            if (i >= track.d1.count) {
                i = track.d1.count - 1
            }
            self.annotations[j].coordinate = track.mapData[i].coordinate
            j += 1
        }
    }
}
