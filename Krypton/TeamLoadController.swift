//
//  TeamLoadController.swift
//  Krypton
//
//  Created by Alex Grinman on 8/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation


class TeamLoadController:UIViewController, UITextFieldDelegate {
    
    
    var joinType:TeamJoinType?
    var teamName:String?
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!

    @IBOutlet weak var detailLabel:UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        detailLabel.text = ""
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)        
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        
        // ensure we don't have a team yet
        if let team = (try? IdentityManager.getTeamIdentity()?.dataManager.withTransaction { try $0.fetchTeam() }) as? Team {
            self.showWarning(title: "Already on team \(team.name)", body: "\(Properties.appName) only supports being on one team. Multi-team support is coming soon!")
            {
                self.dismiss(animated: true, completion: nil)
            }
            return
        }
        
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)

        dispatchAfter(delay: 0.3) {
            self.loadTeam()
        }
    }
    
    func loadTeam() {
        switch joinType! {
        case .directInvite(let teamIdentity):
            self.loadJoin(with: teamIdentity)

        case .indirectInvite(let invite):
            self.loadJoin(with: invite)
                        
        case .createFromApp(let settings):
            self.teamName = settings.name
            self.loadCreate()

        }
    }
    
    func loadJoin(with teamIdentity:TeamIdentity) {
        let service = TeamService.temporary(for: teamIdentity)
        
        dispatchAsync {
            do {
                let result = try service.getVerifiedTeamUpdatesSync()
                switch result {
                case .error(let e):
                    throw e
                    
                case .result(let service):
                    self.teamName = try? service.teamIdentity.dataManager.withTransaction { try $0.fetchTeam() }.name
                    
                    dispatchMain {
                        self.performSegue(withIdentifier: "showTeamInvite", sender: teamIdentity)
                    }
                }
                
                
            } catch {
                self.showError(message: "Could not fetch team information. Reason: \(error).")
                return
            }

        }
    }
    
    func loadJoin(with invite:SigChain.IndirectInvitation.Secret) {
        
        var teamIdentity:TeamIdentity
        do {
            teamIdentity = try TeamIdentity.newMember(email: "",
                                                      checkpoint: invite.lastBlockHash,
                                                      initialTeamPublicKey: invite.initialTeamPublicKey)
            
        } catch {
            self.showError(message: "Could not generate team identity. Reason: \(error).")
            return
        }
        
        let service = TeamService.temporary(for: teamIdentity)

        dispatchAsync {
            do {
                switch try service.getTeamSync(using: invite) {
                case .error(let e):
                    throw e
                    
                case .result(let service):
                    teamIdentity = service.teamIdentity
                    self.teamName = try? teamIdentity.dataManager.withTransaction { try $0.fetchTeam() }.name

                    dispatchMain {
                        self.performSegue(withIdentifier: "showTeamInvite", sender: teamIdentity)
                    }
                    
                }
            } catch {
                self.showError(message: "Could not fetch team information. Reason: \(error).")
            }
        }

    }
    
    func loadCreate() {
        self.performSegue(withIdentifier: "showTeamInvite", sender: nil)
    }
    
    func showError(message:String) {
        dispatchMain {
            self.detailLabel.text = message
            self.detailLabel.textColor = UIColor.reject
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject

            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let teamInviteController = segue.destination as? TeamInvitationController
        {
            teamInviteController.joinType = joinType
            teamInviteController.teamIdentity = sender as? TeamIdentity
            teamInviteController.teamName = self.teamName
        }
    }
    

    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
}
