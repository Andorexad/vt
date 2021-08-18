//
//  ViewController.swift
//  VT_final
//
//  Created by Andi Xu on 8/17/21.
//

import UIKit
import CoreData
import MapKit

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var isEditingSwitch: UISwitch!

    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var pins:[Pin]?
    
    let locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        return manager
    }()
    
    func setUpMapView() {
        self.mapView.delegate = self
        self.mapView.isZoomEnabled = true
        self.mapView.isScrollEnabled = true
        title = "Travel Locations Map"
        
        mapView.showsCompass = true
        mapView.showsScale = true
        currentLocation()
    }
    
    func currentLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        try? locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()
    }
    
    func fetchPins(){
        do {
            self.pins=try context.fetch(Pin.fetchRequest())
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    
    
    
    func setUpPins() {
        
        var annotations = [MKPointAnnotation]()
        
        for dictionary in pins ?? [] {
            let lat = CLLocationDegrees((dictionary.value(forKeyPath: "latitude") as? Double) ?? 0.0 )
            let long = CLLocationDegrees((dictionary.value(forKeyPath: "longitude") as? Double) ?? 0.0 )
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotations.append(annotation)
        }
        self.mapView.addAnnotations(annotations)
    }
    
    func refresh(){
        self.mapView.removeAnnotations(mapView.annotations)
        self.setUpPins()
    }

    
    // MARK: View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpMapView()
        
        let uiLPGR = UILongPressGestureRecognizer(target: self, action: #selector(addPin(longGesture:)))
        self.mapView.addGestureRecognizer(uiLPGR)
            
        fetchPins()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refresh()
    }
    
    // MARK: Pin Operation
    
    @objc func addPin(longGesture: UIGestureRecognizer) {
        
        if longGesture.state == .began {
            let touchedPoint = longGesture.location(in: mapView)
            let newCoords = mapView.convert(touchedPoint, toCoordinateFrom: mapView)
            let pressedLocation = CLLocation(latitude: newCoords.latitude, longitude: newCoords.longitude)
        
            let newPin=Pin(context: self.context)
            newPin.latitude = pressedLocation.coordinate.latitude
            newPin.longitude = pressedLocation.coordinate.longitude
            do {
                try self.context.save()
            } catch {
                print ("cannot save new pin to core data")
            }
            self.fetchPins()
            self.refresh()
        }
    }
    
    func tapOnPin(of: MKAnnotation, editMode: Bool) {
        let coord = of.coordinate
        for pin in pins ?? [] {
            if pin.latitude == coord.latitude && pin.longitude == coord.longitude {
                if (editMode){
                    do {
                        self.context.delete(pin)
                        try? self.context.save()
                    } catch {
                        print("delete pin failed")
                    }
                    break
                } else {
                    performSegue(withIdentifier: "ToPhotoAlbum", sender: pin)
                }
                
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? AlbumViewController {
            guard let passedPin = sender as? Pin else {
                return
            }
            vc.pin = passedPin
        }
    }
    
    
    // MARK: MapDelegate
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else {
            return
        }
        tapOnPin(of: annotation, editMode: isEditingSwitch.isOn)
    
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .red
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        let defaults = UserDefaults.standard
        let locationData = ["lat": mapView.centerCoordinate.latitude
            , "long": mapView.centerCoordinate.longitude
            , "latDelta": mapView.region.span.latitudeDelta
            , "longDelta": mapView.region.span.longitudeDelta]
        defaults.set(locationData, forKey: "userMapRegion")
    }
    
    // MARK: CLLocationManager
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let userCoordinate = UserDefaults.standard.dictionary(forKey: "userMapRegion") {
            let center = CLLocationCoordinate2D(latitude: userCoordinate["lat"] as! Double, longitude: userCoordinate["long"] as! Double)
            let span = MKCoordinateSpan(latitudeDelta: userCoordinate["latDelta"] as! Double, longitudeDelta: userCoordinate["longDelta"] as! Double)
            let userRegion = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(userRegion, animated: true)
        } else {
            let location = locations.last! as CLLocation
            let currentLocation = location.coordinate
            let coordinateRegion = MKCoordinateRegion(center: currentLocation, latitudinalMeters: 100000, longitudinalMeters: 100000)
            mapView.setRegion(coordinateRegion, animated: true)
        }
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
       print(error.localizedDescription)
    }
    
   


}




