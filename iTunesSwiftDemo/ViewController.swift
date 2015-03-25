//
//  ViewController.swift
//  iTunesSwiftDemo
//
//  Created by Ben Jones on 3/25/15.
//  Copyright (c) 2015 SocialCode Inc. All rights reserved.
//

import UIKit

class MediaCell : UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel?
    @IBOutlet weak var descriptionLabel: UILabel?
    @IBOutlet weak var artworkImageView: UIImageView?
    @IBOutlet weak var collectionNameLabel: UILabel?

    var imageDownloadTask: NSURLSessionDataTask?
}

class ViewController: UITableViewController {
    var results = Array<[String : AnyObject]>()

    let session: NSURLSession = {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let sess = NSURLSession(configuration: config)
        return sess
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func clearResults() {
        results = []
        tableView?.reloadData()
    }

    // NOTE: This is the worst common thing you'll ever do in Swift! SwiftyJSON or others make this nicer!
    func handleSearchResults(forData data: NSData) {
        var jsonError: NSError?
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments, error: &jsonError) as? [NSObject : AnyObject] {
            if let results = json["results"] as? Array<[String : AnyObject]> {
                self.results = results
                tableView?.reloadData()
            }
        } else {
            println("JSON Error \(jsonError)")
        }
    }

    func searchFor(#term: String) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true

        clearResults()

        // NOTE: Below are two implicitly unwrapped optionals, these should be viewed as warning signs! There's many tricks to fix this,
        //       but in the interest of demo clearity I'm not using one of my favorite tricks: applicative Functors, or monad bind operator tricks
        let encodedTerm = term.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let urlString = "https://itunes.apple.com/search?country=US&term=\(encodedTerm)"
        let request = NSURLRequest(URL: NSURL(string: urlString)!)

        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false

            if let httpResponse = response as? NSHTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    dispatch_async(dispatch_get_main_queue()) {
                        self.handleSearchResults(forData: data)
                    }
                default:
                    let body = NSString(data: data, encoding: NSUTF8StringEncoding)
                    dispatch_async(dispatch_get_main_queue()) {
                        let controller = UIAlertController(title: "Error", message: "Received an error from the server", preferredStyle: .Alert)
                        let action = UIAlertAction(title: "Ok", style: .Default) { _ in
                            controller.dismissViewControllerAnimated(true, completion: nil)
                        }

                        controller.addAction(action)

                        self.presentViewController(controller, animated: true, completion: nil)
                    }
                }
            }
        }

        task.resume()
    }
}

// MARK: UISearchBarDelegate
extension ViewController : UISearchBarDelegate {
    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        return true
    }

    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchFor(term: searchBar.text)
    }
}

// MARK: UITableViewDataSource
extension ViewController : UITableViewDataSource {
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "mediaCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as MediaCell

        let record = results[indexPath.row]

        cell.nameLabel?.text = record["artistName"] as? String
        cell.descriptionLabel?.text = record["primaryGenreName"] as? String
        cell.collectionNameLabel?.text = record["collectionName"] as? String

        if let task = cell.imageDownloadTask {
            task.cancel()
        }

        cell.artworkImageView?.image = nil
        if let artworkUrlString = record["artworkUrl100"] as? String {
            let imageUrl = NSURL(string: artworkUrlString)!
            cell.imageDownloadTask = session.dataTaskWithURL(imageUrl) { (data, response, error) in
                if error != nil {
                    println(error)
                } else {
                    if let httpResponse = response as? NSHTTPURLResponse {
                        switch httpResponse.statusCode {
                        case 200:
                            let image = UIImage(data: data)
                            dispatch_async(dispatch_get_main_queue()) { _ =
                                cell.artworkImageView?.image = image
                            }
                        default:
                            println("Couldn't load image from \(artworkUrlString)")
                        }
                    }
                }
            }

            cell.imageDownloadTask?.resume()
        }

        return cell
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
}
