//
//  AlbumViewController.swift
//  VT_final
//
//  Created by Andi Xu on 8/17/21.
//

import UIKit
import MapKit
import CoreData

class AlbumViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, MKMapViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var photoCollectionView: UICollectionView!
    
    /// var with core data
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var pin: Pin!
    var fetchedResultsController:NSFetchedResultsController<Photo>!
    
    /// view setup
    let collectionCellID = "CollectionViewCell"
    let actInd=UIActivityIndicatorView()
    let sectionInsets = UIEdgeInsets(top: 5.0,
    left: 5.0,
    bottom: 5.0,
    right: 5.0)
    
    
    var blockOperation = BlockOperation()
    var photosURL: [URL?] = []
    
    
    // MARK: set up methods
    func setUpMap() {
        self.mapView.delegate = self
        self.mapView.isZoomEnabled = false
        self.mapView.isScrollEnabled = false
        
        print("pin's lat\(pin.latitude) and pin's long: \(pin.longitude)")
        let clLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        centerMapOnLocation(clLocation , mapView: self.mapView)
        setUpPin()
    }
    
    func setUpGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongGesture(gesture:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        longPressGesture.delaysTouchesBegan = true
        photoCollectionView.addGestureRecognizer(longPressGesture)
    }
    
    func setUpCollection() {
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self
        
        flowLayout.scrollDirection = .vertical
        self.photoCollectionView.collectionViewLayout = self.flowLayout
    }
    
    func setUpCollectionCell(){
        let itemsPerRow:CGFloat=5.0
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = photoCollectionView.frame.size.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        flowLayout.itemSize = CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    func showActivityIndicator(uiView: UIView) {
        let container: UIView = UIView()
        container.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        container.backgroundColor = .clear
        actInd.style = UIActivityIndicatorView.Style.large
        actInd.center = self.view.center
        container.addSubview(actInd)
        self.view.addSubview(container)
    }
    
    fileprivate func setupFetchedResultsController() {
        actInd.startAnimating()
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", pin)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "photoOrder", ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
        actInd.stopAnimating()
    }
    
    /// fetch photoData
    func fetchFlickrPhotoURLs() {
        
        actInd.startAnimating()
        newCollectionButton.isEnabled = false
        photosURL=[]
        
        FlickrClient.search(lat: pin!.latitude, long: pin!.longitude) { flickrPhotos, error in
            // for each round of fetch, will generate a new array of photoID
            if error == nil {
                var id: Int = 0
                for photo in flickrPhotos {
                    let url = FlickrClient.photoPathURL(photo: photo)
                    self.photosURL.append(url)
                    let newPhoto = Photo(context:self.context)
                    newPhoto.photoOrder=Int16(id)
                    newPhoto.pin=self.pin
                    try? self.context.save()
                    self.photoCollectionView.reloadData()
                    id+=1
                }
                id = 0
            }
        }
        setupFetchedResultsController()
        self.photoCollectionView.reloadData()
        actInd.stopAnimating()
        newCollectionButton.isEnabled = true
    }
    
    
    /// gesture
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        switch(gesture.state) {
        case .began:
            guard let selectedIndexPath = photoCollectionView.indexPathForItem(at: gesture.location(in: photoCollectionView)) else {
                break
            }
            photoCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            photoCollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case .ended:
            photoCollectionView.endInteractiveMovement()
        default:
            photoCollectionView.cancelInteractiveMovement()
        }
        
    }
    
    @IBAction func getNewCollection(_ sender: Any){
        if let  objects = self.fetchedResultsController.fetchedObjects {
            let photosToHide = self.photoCollectionView.indexPathsForVisibleItems
            for photoToHide in photosToHide {
                self.photoCollectionView.cellForItem(at: photoToHide)!.isHidden = true
            }
            actInd.startAnimating()
            for object in objects{
                self.context.performAndWait {
                    self.context.delete(object)
                    try? self.context.save()
                }
            }
        }
        self.photoCollectionView.reloadData()
        self.photoCollectionView!.numberOfItems(inSection: 0)
        self.context.refreshAllObjects()
        try? self.context.save()
        self.fetchFlickrPhotoURLs()
    }
    
    func centerMapOnLocation(_ location: CLLocation, mapView: MKMapView) {
        let regionRadius: CLLocationDistance = 1000
        let coordinateRegion = MKCoordinateRegion(center: location.coordinate,
                                                  latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func setUpPin() {
        var annotations = [MKPointAnnotation]()
        let lat = CLLocationDegrees((pin.value(forKeyPath: "latitude") as? Double) ?? 0.0 )
        let long = CLLocationDegrees((pin.value(forKeyPath: "longitude") as? Double) ?? 0.0 )
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotations.append(annotation)
        self.mapView.addAnnotations(annotations)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        return true
    }
    
    //MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpMap()
        setUpGesture()
        setUpCollection()
        setUpCollectionCell()
        setupFetchedResultsController()
        showActivityIndicator(uiView: actInd)
        
        //Fetching the image urls from Flickr
        if (fetchedResultsController.fetchedObjects!.isEmpty == true) {
            print("No previous download")
            fetchFlickrPhotoURLs()
        }
                    
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupFetchedResultsController()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedResultsController = nil
    }
    
    // MARK: CollectionViewDelegate + Datasource
  
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
     
        if sourceIndexPath.item < destinationIndexPath.item {
            
            for i in sourceIndexPath.item+1...destinationIndexPath.item {
                self.fetchedResultsController.object(at: IndexPath(item: i, section: 0)).photoOrder -= 1
            }
            self.fetchedResultsController.object(at: sourceIndexPath).photoOrder = Int16(destinationIndexPath.item+1)
        } else {
            
            for i in (destinationIndexPath.item...sourceIndexPath.item-1).reversed() {
                self.fetchedResultsController.object(at: IndexPath(item: i, section: 0)).photoOrder += 1
                
            }
            self.fetchedResultsController.object(at: sourceIndexPath).photoOrder = Int16(destinationIndexPath.item+1)
        }
        if self.photosURL.count != 0 {
            let temp = self.photosURL[sourceIndexPath.item]
            self.photosURL.remove(at: sourceIndexPath.item)
            self.photosURL.insert(temp, at: destinationIndexPath.item)
        }
        try? self.context.save()
        self.setupFetchedResultsController()
    }
    
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    // Populate the cells
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collectionCellID , for: indexPath) as! CollectionViewCell
        if let cellPhotoData = self.fetchedResultsController.object(at: indexPath).imageData {
            print("adding a photo in the album")
            cell.imageVie.image = UIImage(data: cellPhotoData)
        } else if  photosURL.count != 0 {
            if let url = photosURL[indexPath.row] {
                cell.actInd.startAnimating()
                FlickrClient.downloadPosterImage(photoURL: url) { (data, error) in
                    if error != nil {
                        print("error in downloading data from a photo")
                    } else {
                        if data != nil {
                            let cellPhoto = self.fetchedResultsController.object(at: indexPath)
                            cellPhoto.imageData = data
                            try? self.context.save()
                            cell.imageVie.image = UIImage(data: data!)
                            cell.actInd.stopAnimating()
                        }
                    }
                }
            }
        }
        return cell
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let objectToDelete = fetchedResultsController.object(at: indexPath)
        self.context.delete(objectToDelete)
        //collectionView.deleteItems(at: [indexPath])
        try? self.context.save()
    }
    
    
}



extension AlbumViewController {
        
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
            case .insert:
                guard let newIndexPath = newIndexPath else {break}
                blockOperation.addExecutionBlock {
                    self.photoCollectionView.insertItems(at: [newIndexPath])
                }
            case .delete:
                guard let indexPath = indexPath else {break}
                blockOperation.addExecutionBlock {
                    self.photoCollectionView.deleteItems(at: [indexPath])
                }
            case .update:
                guard let indexPath = indexPath else {break}
                blockOperation.addExecutionBlock {
                   DispatchQueue.main.async {
                    self.photoCollectionView.reloadItems(at: [indexPath])
                    }
                }
            case .move:
                guard let newIndexPath = newIndexPath else {break}
                blockOperation.addExecutionBlock {
                    DispatchQueue.main.async {
                    self.photoCollectionView.moveItem(at: indexPath!, to: newIndexPath)
                    }
                }
            default:
                fatalError("Invalid change type in controller(_:didChange:atSectionIndex:for:). Only .insert/delete/move/update should be possible.")
        }
        
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperation = BlockOperation()
        
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        photoCollectionView?.performBatchUpdates({self.blockOperation.start()}, completion: nil)
    }
}

extension AlbumViewController {

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
}
