//
//  Copyright (c) 2016 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import Firestore
import SDWebImage

func priceString(from price: Int) -> String {
  let priceText: String
  switch price {
  case 1:
    priceText = "$"
  case 2:
    priceText = "$$"
  case 3:
    priceText = "$$$"
  case _:
    priceText = ""
  }

  return priceText
}

private func randomImageURL() -> URL {
  let randomImageNumber = Int(arc4random_uniform(22)) + 1
  let randomImageURLString =
  "https://storage.googleapis.com/firestorequickstarts.appspot.com/food_\(randomImageNumber).png"
  return URL(string: randomImageURLString)!
}

class RestaurantsTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

  @IBOutlet var tableView: UITableView!
  @IBOutlet var activeFiltersStackView: UIStackView!
  @IBOutlet var stackViewHeightConstraint: NSLayoutConstraint!

  @IBOutlet var cityFilterLabel: UILabel!
  @IBOutlet var categoryFilterLabel: UILabel!
  @IBOutlet var priceFilterLabel: UILabel!

  private var restaurants: [Restaurant] = []
  private var documents: [DocumentSnapshot] = []

  fileprivate var query: Query? {
    didSet {
      if let listener = listener {
        listener.remove()
        observeQuery()
      }
    }
  }

  private var listener: FIRListenerRegistration?

  fileprivate func observeQuery() {
    guard let query = query else { return }
    stopObserving()

    // Display data from Firestore, part one

    listener = query.addSnapshotListener { [unowned self] (snapshot, error) in
      guard let snapshot = snapshot else {
        print("Error fetching snapshot results: \(error!)")
        return
      }
      let models = snapshot.documents.map { (document) -> Restaurant in
        if let model = Restaurant(dictionary: document.data()) {
          return model
        } else {
          // Don't use fatalError here in a real app.
          fatalError("Unable to initialize type \(Restaurant.self) with dictionary \(document.data())")
        }
      }
      self.restaurants = models
      self.documents = snapshot.documents
      self.tableView.reloadData()
    }
  }

  fileprivate func stopObserving() {
    listener?.remove()
  }

  fileprivate func baseQuery() -> Query {
    return Firestore.firestore().collection("restaurants").limit(to: 50)
  }

  lazy private var filters: (navigationController: UINavigationController,
                             filtersController: FiltersViewController) = {
    return FiltersViewController.fromStoryboard(delegate: self)
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.dataSource = self
    tableView.delegate = self
    query = baseQuery()
    stackViewHeightConstraint.constant = 0
    activeFiltersStackView.isHidden = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    observeQuery()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let auth = FUIAuth.defaultAuthUI()!
    if auth.auth?.currentUser == nil {
      auth.providers = [FUIGoogleAuth()]
      present(auth.authViewController(), animated: true, completion: nil)
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopObserving()
  }

  @IBAction func didTapPopulateButton(_ sender: Any) {
    let words = ["Bar", "Fire", "Grill", "Drive Thru", "Place", "Best", "Spot", "Prime", "Eatin'"]
    let cities = ["San Francisco", "Mountain View", "Palo Alto", "Redwood City", "San Mateo",
                  "Cupertino", "San Jose", "Daly City", "Millbrae", "Belmont"]
    let categories = ["Pizza", "Burgers", "American", "Dim Sum", "Pho", "Mexican", "Hot Pot"]

    for _ in 0 ..< 20 {
      let randomIndexes = (Int(arc4random_uniform(UInt32(words.count))),
                           Int(arc4random_uniform(UInt32(words.count))))
      let name = words[randomIndexes.0] + " " + words[randomIndexes.1]
      let category = categories[Int(arc4random_uniform(UInt32(categories.count)))]
      let city = cities[Int(arc4random_uniform(UInt32(cities.count)))]
      let price = Int(arc4random_uniform(3)) + 1
      let ratingCount = 0
      let averageRating: Float = 0

      // Basic writes

      let collection = Firestore.firestore().collection("restaurants")

      let restaurant = Restaurant(
        name: name,
        category: category,
        city: city,
        price: price,
        ratingCount: ratingCount,
        averageRating: averageRating
      )

      collection.addDocument(data: restaurant.dictionary)
    }
  }

  @IBAction func didTapClearButton(_ sender: Any) {
    filters.filtersController.clearFilters()
    controller(filters.filtersController, didSelectCategory: nil, city: nil, price: nil, sortBy: nil)
  }

  @IBAction func didTapFilterButton(_ sender: Any) {
    present(filters.navigationController, animated: true, completion: nil)
  }

  deinit {
    listener?.remove()
  }

  // MARK: - UITableViewDataSource

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "RestaurantTableViewCell",
                                             for: indexPath) as! RestaurantTableViewCell
    let restaurant = restaurants[indexPath.row]
    cell.populate(restaurant: restaurant)
    return cell
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return restaurants.count
  }

  // MARK: - UITableViewDelegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let controller = RestaurantDetailViewController.fromStoryboard()
    controller.titleImageURL = randomImageURL()
    controller.restaurant = restaurants[indexPath.row]
    controller.restaurantReference = documents[indexPath.row].reference
    self.navigationController?.pushViewController(controller, animated: true)
  }

  func tableView(_ tableView: UITableView,
                 commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {

      // Deleting documents

      let reference = documents[indexPath.row].reference
      reference.delete { error in
        if let error = error {
          print("Error deleting document: \(error)")
        }
      }

    }
  }

}

extension RestaurantsTableViewController: FiltersViewControllerDelegate {

  func query(withCategory category: String?, city: String?, price: Int?, sortBy: String?) -> Query {
    var filtered = baseQuery()

    // Advanced queries

    if let category = category, !category.isEmpty {
      filtered = filtered.whereField("category", isEqualTo: category)
    }

    if let city = city, !city.isEmpty {
      filtered = filtered.whereField("city", isEqualTo: city)
    }

    if let price = price {
      filtered = filtered.whereField("price", isEqualTo: price)
    }

    if let sortBy = sortBy, !sortBy.isEmpty {
      filtered = filtered.order(by: sortBy)
    }

    return filtered
  }

  func controller(_ controller: FiltersViewController,
                  didSelectCategory category: String?,
                  city: String?,
                  price: Int?,
                  sortBy: String?) {
    let filtered = query(withCategory: category, city: city, price: price, sortBy: sortBy)

    if let category = category, !category.isEmpty {
      categoryFilterLabel.text = category
      categoryFilterLabel.isHidden = false
    } else {
      categoryFilterLabel.isHidden = true
    }

    if let city = city, !city.isEmpty {
      cityFilterLabel.text = city
      cityFilterLabel.isHidden = false
    } else {
      cityFilterLabel.isHidden = true
    }

    if let price = price {
      priceFilterLabel.text = priceString(from: price)
      priceFilterLabel.isHidden = false
    } else {
      priceFilterLabel.isHidden = true
    }

    self.query = filtered
    observeQuery()
  }

}

class RestaurantTableViewCell: UITableViewCell {
  
  @IBOutlet private var thumbnailView: UIImageView!

  @IBOutlet private var nameLabel: UILabel! {
    didSet {
      nameLabel.font = UIFont.preferredFont(forTextStyle: .body)
    }
  }
  
  @IBOutlet var starsView: ImmutableStarsView!

  @IBOutlet private var cityLabel: UILabel! {
    didSet {
      cityLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    }
  }
  @IBOutlet private var categoryLabel: UILabel! {
    didSet {
      categoryLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    }
  }
  @IBOutlet private var priceLabel: UILabel! {
    didSet {
      priceLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
      priceLabel.textColor = UIColor(red: 60 / 255, green: 210 / 255, blue: 64 / 255, alpha: 1)
    }
  }

  func populate(restaurant: Restaurant) {

    // Displaying data, part two

    nameLabel.text = restaurant.name
    cityLabel.text = restaurant.city
    categoryLabel.text = restaurant.category
    starsView.rating = Int(restaurant.averageRating.rounded())
    priceLabel.text = priceString(from: restaurant.price)

    let imageURL = randomImageURL()
    thumbnailView.sd_setImage(with: imageURL)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    thumbnailView.sd_cancelCurrentImageLoad()
  }

}
