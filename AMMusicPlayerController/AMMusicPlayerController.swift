//
//  AMMusicPlayerController.swift
//  AMMusicPlayerController
//
//  Created by YOSHIMUTA YOHEI on 2019/09/25.
//  Copyright © 2019 YOSHIMUTA YOHEI. All rights reserved.
//

import RxMusicPlayer
import RxSwift
import SPStorkController
import UIKit

public class AMMusicPlayerController: UIViewController {
    // Music player.
    public private(set) var player: RxMusicPlayer!

    @IBOutlet private var tableView: UITableView!

    private let disposeBag = DisposeBag()
    private var lightStatusBar: Bool = false
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return lightStatusBar ? .lightContent : .default
    }

    // swiftlint:disable:next weak_delegate
    public var tableViewDelegate = AMMusicPlayerTableViewDeletegate()
    public var tableViewDataSource = AMMusicPlayerTableViewDataSource()
    public weak var delegate: AMMusicPlayerDelegate?

    private var config: AMMusicPlayerConfig!

    /**
     Initialize a controller.
     */
    public static func make(player: RxMusicPlayer,
                            config: AMMusicPlayerConfig = AMMusicPlayerConfig.default)
        -> AMMusicPlayerController {
        let controller = UIStoryboard(name: "AMMusicPlayerController", bundle: Bundle(for: self))
            // swiftlint:disable:next force_cast
            .instantiateInitialViewController() as! AMMusicPlayerController
        controller.player = player
        controller.config = config
        return controller
    }

    /**
     Initialize a controller.
     */
    public static func make(urls: [URL] = [],
                            index: Int = 0,
                            config: AMMusicPlayerConfig = AMMusicPlayerConfig.default)
        -> AMMusicPlayerController? {
        guard let player = RxMusicPlayer(items: urls.map { RxMusicPlayerItem(url: $0) }) else {
            return nil
        }
        player.playIndex = index
        return make(player: player, config: config)
    }

    /**
     Present the player view controller.
     */
    public func presentPlayer(src: UIViewController,
                              animated flag: Bool = true,
                              completion: (() -> Void)? = nil) {
        let transitionDelegate = SPStorkTransitioningDelegate()
        transitionDelegate.storkDelegate = self
        transitionDelegate.confirmDelegate = self
        transitioningDelegate = transitionDelegate
        modalPresentationStyle = .custom
        src.present(self, animated: flag, completion: completion)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        self.overrideUserInterfaceStyle = .light
        modalPresentationCapturesStatusBarAppearance = true

        tableViewDelegate.tableView = tableView
        tableView.delegate = tableViewDelegate
        tableViewDataSource.player = player
        tableViewDataSource.config = config
        tableView.dataSource = tableViewDataSource
        tableView.tableFooterView = UIView(frame: .zero)

        player.rx.currentItemLyrics()
            .distinctUntilChanged()
            .do(onNext: { [weak self] _ in
                self?.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)],
                                           with: UITableView.RowAnimation.automatic)
            })
            .drive()
            .disposed(by: disposeBag)

        tableViewDataSource.rx.playerDidFail
            .asDriver()
            .do(onNext: { [weak self] err in
                self?.delegate?.musicPlayerControllerDidFail(controller: self,
                                                             err: AMMusicPlayerError(err: err))
            })
            .drive()
            .disposed(by: disposeBag)

        updateLayout(with: view.frame.size)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        lightStatusBar = true
        UIView.animate(withDuration: 0.3) { () -> Void in
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateLayout(with: view.frame.size)
    }

    func updateLayout(with size: CGSize) {
        tableView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }

    @objc func dismissAction() {
        SPStorkController.dismissWithConfirmation(controller: self, completion: nil)
    }
}

extension AMMusicPlayerController: SPStorkControllerConfirmDelegate {

    open var needConfirm: Bool {
        return config.confirmConfig.needConfirm
    }

    open func confirm(_ completion: @escaping (Bool) -> Void) {
        let c = config.confirmConfig
        let alertController = UIAlertController(title: c.title,
                                                message: c.message,
                                                preferredStyle: .actionSheet)

        let destructive = UIAlertAction(title: c.confirmActionTitle,
                                        style: .destructive) { _ in
            completion(true)
        }
        alertController.addAction(destructive)

        let cancel = UIAlertAction(title: c.cancelActionTitle,
                                   style: .cancel) { _ in
            completion(false)
        }
        alertController.addAction(cancel)

        present(alertController, animated: true)
    }
}

extension AMMusicPlayerController: SPStorkControllerDelegate {

    public func didDismissStorkByTap() {
        delegate?.musicPlayerControllerDidDismissByTap()
    }

    public func didDismissStorkBySwipe() {
        delegate?.musicPlayerControllerDidDismissBySwipe()
    }
}
