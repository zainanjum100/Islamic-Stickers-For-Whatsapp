//
// Copyright (c) WhatsApp Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit
import GoogleMobileAds



class AllStickerPacksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, GADBannerViewDelegate,GADInterstitialDelegate {

    @IBOutlet private weak var stickerPacksTableView: UITableView!
    @IBOutlet weak var bannerView: GADBannerView!
    var interstitial: GADInterstitial!
    var INTER_ADD_ID = "ca-app-pub-4639632909284359/2714367485"
    var BANNER_ADD_ID = "ca-app-pub-4639632909284359/7611470942"

    private var needsFetchStickerPacks = true
    private var stickerPacks: [StickerPack] = []
    private var selectedIndex: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .automatic
        }
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.alpha = 0.0;
        stickerPacksTableView.register(UINib(nibName: "StickerPackTableViewCell", bundle: nil), forCellReuseIdentifier: "StickerPackCell")
        stickerPacksTableView.tableFooterView = UIView(frame: .zero)
        
        self.needsFetchStickerPacks = false
        self.fetchStickerPacks()
        
        interstitial = GADInterstitial(adUnitID: INTER_ADD_ID)
        let request = GADRequest()
        interstitial.load(request)
        
        
        bannerView.adUnitID = BANNER_ADD_ID
        bannerView.rootViewController = self
        bannerView.adSize = kGADAdSizeSmartBannerPortrait
        bannerView.delegate = self
        bannerView.load(GADRequest())

        
    }
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        bannerView.isHidden = false
    }
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        bannerView.isHidden = true
    }
    
    func createAndLoadInterstitial() -> GADInterstitial {
        let interstitial = GADInterstitial(adUnitID: "ca-app-pub-3940256099942544/1033173712")
        interstitial.delegate = self
        interstitial.load(GADRequest())
        return interstitial
    }
    
    func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        interstitial = createAndLoadInterstitial()
    }
    //create add
    func createAd() -> GADInterstitial {
        let inter = GADInterstitial(adUnitID: INTER_ADD_ID)
        inter.load(GADRequest())
        return inter
    }



    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let selectedIndex = self.selectedIndex {
            stickerPacksTableView.deselectRow(at: selectedIndex, animated: true)
        }
    }


    private func fetchStickerPacks() {
        let loadingAlert: UIAlertController = UIAlertController(title: "Loading sticker packs", message: "\n\n", preferredStyle: .alert)
        loadingAlert.addSpinner()
        present(loadingAlert, animated: true, completion: nil)

        do {
            try StickerPackManager.fetchStickerPacks(fromJSON: StickerPackManager.stickersJSON(contentsOfFile: "contents")) { stickerPacks in
                loadingAlert.dismiss(animated: false, completion: {
                    self.navigationController?.navigationBar.alpha = 1.0;

                    if stickerPacks.count > 1 {
                        self.stickerPacks = stickerPacks
                        self.stickerPacksTableView.reloadData()
                    } else {
                        self.show(stickerPack: stickerPacks[0], animated: false)
                    }
                })
            }
        } catch StickerPackError.fileNotFound {
            fatalError("sticker_packs.wasticker not found.")
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private func show(stickerPack: StickerPack, animated: Bool) {
        // "stickerPackNotAnimated" still animates the push transition on iOS 8 and earlier.
        let identifier = animated ? "stickerPackAnimated" : "stickerPackNotAnimated"
        performSegue(withIdentifier: identifier, sender: stickerPack)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? StickerPackViewController,
            let stickerPack = sender as? StickerPack {
            vc.title = stickerPack.name
            vc.stickerPack = stickerPack
            vc.navigationItem.hidesBackButton = stickerPacks.count <= 1
        }
    }

    // MARK: Tableview

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stickerPacks.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: StickerPackTableViewCell = tableView.dequeueReusableCell(withIdentifier: "StickerPackCell") as! StickerPackTableViewCell
        cell.stickerPack = stickerPacks[indexPath.row]

        let addButton: UIButton = UIButton(type: .contactAdd)
        addButton.tag = indexPath.row
        addButton.isEnabled = Interoperability.canSend()
        addButton.addTarget(self, action: #selector(addButtonTapped(button:)), for: .touchUpInside)
        cell.accessoryView = addButton

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath

        show(stickerPack: stickerPacks[indexPath.row], animated: true)
        
        if (interstitial.isReady) {
            interstitial.present(fromRootViewController: self)
            interstitial = createAd()
        }

    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let navigationBar = navigationController?.navigationBar {
            let contentInset: UIEdgeInsets = {
                if #available(iOS 11.0, *) {
                    return scrollView.adjustedContentInset
                } else {
                    return scrollView.contentInset
                }
            }()
            if scrollView.contentOffset.y <= -contentInset.top {
                navigationBar.shadowImage = UIImage()
            } else {
                navigationBar.shadowImage = nil
            }
        }
    }

    @objc func addButtonTapped(button: UIButton) {
        let loadingAlert: UIAlertController = UIAlertController(title: "Sending to WhatsApp", message: "\n\n", preferredStyle: .alert)
        loadingAlert.addSpinner()
        present(loadingAlert, animated: true, completion: nil)

        stickerPacks[button.tag].sendToWhatsApp { completed in
            loadingAlert.dismiss(animated: true, completion: nil)
        }
    }
}
