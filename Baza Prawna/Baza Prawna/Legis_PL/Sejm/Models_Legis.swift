//
//  Models_Legis.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 03/11/2025.
//

import Foundation

// MARK: - Search Parameters
struct LegislacjaSearchParameters {
    var title: String?
    /// When set, resolves via `GET .../processes/{num}` (not a list query).
    var number: String?
    /// Mapped to Sejm query `modifiedSince` (`yyyy-MM-dd` or ISO local date-time). No `dateTo` on the list API.
    var dateFrom: String?
    var dateTo: String?
    /// When `true`, uses `GET .../processes/passed`. `false` uses the general list (do not send `passed=false`; edge rejects it).
    var passed: Bool?
    var offset: Int
    var limit: Int
    /// Ignored for network requests — Sejm `sort` query is often blocked; list order is server-defined.
    var sort_by: String?
}

// MARK: - API Response Models
// The API returns an array directly, not wrapped in an object
typealias ProcessesResponse = [LegislativeProcess]

struct LegislativeProcess: Codable, Identifiable {
    let term: Int
    let number: String
    let title: String?
    let titleFinal: String?
    let description: String?
    let documentDate: String?
    let documentType: String?
    let documentTypeEnum: String?
    let address: String?
    let displayAddress: String?
    let ELI: String?
    let processStartDate: String?
    let changeDate: String?
    let comments: String?
    let passed: Bool?
    let stages: [ProcessStage]?
    let UE: String?
    let shortenProcedure: Bool?
    let links: [StageLink]?
    
    // Computed property for Identifiable
    var id: String {
        "\(term)-\(number)"
    }
    
    enum CodingKeys: String, CodingKey {
        case term
        case number
        case title
        case titleFinal
        case description
        case documentDate
        case documentType
        case documentTypeEnum
        case address
        case displayAddress
        case ELI
        case processStartDate
        case changeDate
        case comments
        case passed
        case stages
        case UE
        case shortenProcedure
        case links
    }
}

struct ProcessStage: Codable, Identifiable {
    let stageName: String
    let date: String?
    let committeeCode: String?
    let children: [ProcessStage]?
    
    // Additional fields that may be present in different stage types
    let printNumber: String?
    let sittingNum: Int?
    let decision: String?
    let comment: String?
    let textAfter3: String?
    let reportFile: String?
    let rapporteurID: String?
    let rapporteurName: String?
    let proposal: String?
    let minorityMotions: [String]?
    let position: String?
    let publisher: String?
    let publicationYear: Int?
    let publicationNumber: String?
    let publicationPosition: String?
    let verdict: String?
    let links: [StageLink]?
    let govermentPositionDate: String?
    
    // Computed property for Identifiable
    var id: String {
        "\(stageName)-\(date ?? "")-\(UUID().uuidString.prefix(8))"
    }
    
    enum CodingKeys: String, CodingKey {
        case stageName
        case date
        case committeeCode
        case children
        case printNumber
        case sittingNum
        case decision
        case comment
        case textAfter3
        case reportFile
        case rapporteurID
        case rapporteurName
        case proposal
        case minorityMotions
        case position
        case publisher
        case publicationYear
        case publicationNumber
        case publicationPosition
        case verdict
        case links
        case govermentPositionDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        stageName = try container.decode(String.self, forKey: .stageName)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        committeeCode = try container.decodeIfPresent(String.self, forKey: .committeeCode)
        children = try container.decodeIfPresent([ProcessStage].self, forKey: .children)
        
        printNumber = try container.decodeIfPresent(String.self, forKey: .printNumber)
        sittingNum = try container.decodeIfPresent(Int.self, forKey: .sittingNum)
        decision = try container.decodeIfPresent(String.self, forKey: .decision)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        textAfter3 = try container.decodeIfPresent(String.self, forKey: .textAfter3)
        reportFile = try container.decodeIfPresent(String.self, forKey: .reportFile)
        rapporteurID = try container.decodeIfPresent(String.self, forKey: .rapporteurID)
        rapporteurName = try container.decodeIfPresent(String.self, forKey: .rapporteurName)
        proposal = try container.decodeIfPresent(String.self, forKey: .proposal)
        
        // Handle minorityMotions which can be either a number or an array
        if let minorityMotionsValue = try? container.decode([String].self, forKey: .minorityMotions) {
            minorityMotions = minorityMotionsValue
        } else if let minorityMotionsInt = try? container.decode(Int.self, forKey: .minorityMotions) {
            // If it's a number, treat as empty array (0) or convert to array if needed
            minorityMotions = minorityMotionsInt == 0 ? [] : nil
        } else {
            minorityMotions = nil
        }
        
        position = try container.decodeIfPresent(String.self, forKey: .position)
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        publicationYear = try container.decodeIfPresent(Int.self, forKey: .publicationYear)
        publicationNumber = try container.decodeIfPresent(String.self, forKey: .publicationNumber)
        publicationPosition = try container.decodeIfPresent(String.self, forKey: .publicationPosition)
        verdict = try container.decodeIfPresent(String.self, forKey: .verdict)
        links = try container.decodeIfPresent([StageLink].self, forKey: .links)
        govermentPositionDate = try container.decodeIfPresent(String.self, forKey: .govermentPositionDate)
    }
}

struct StageLink: Codable {
    let href: String
    let rel: String?
    
    enum CodingKeys: String, CodingKey {
        case href
        case rel
    }
}

// MARK: - Passed Status Options
enum PassedStatusOption: String, CaseIterable {
    case all
    case passed
    case notPassed
    
    var displayName: String {
        switch self {
        case .all: return "wszystkie"
        case .passed: return "uchwalone"
        case .notPassed: return "nie uchwalone"
        }
    }
    
    var boolValue: Bool? {
        switch self {
        case .all: return nil
        case .passed: return true
        case .notPassed: return false
        }
    }
}

// MARK: - Committee Sittings
struct CommitteeSitting: Codable, Identifiable {
    let agenda: String?
    let closed: Bool?
    let code: String?
    let date: String?
    let endDateTime: String?
    let num: Int?
    let remote: Bool?
    let room: String?
    let startDateTime: String?
    let status: String?
    let video: [CommitteeVideo]?
    
    var id: String {
        "\(code ?? "")-\(num ?? 0)-\(date ?? "")"
    }
    
    enum CodingKeys: String, CodingKey {
        case agenda
        case closed
        case code
        case date
        case endDateTime
        case num
        case remote
        case room
        case startDateTime
        case status
        case video
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        agenda = try container.decodeIfPresent(String.self, forKey: .agenda)
        closed = try container.decodeIfPresent(Bool.self, forKey: .closed)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        endDateTime = try container.decodeIfPresent(String.self, forKey: .endDateTime)
        num = try container.decodeIfPresent(Int.self, forKey: .num)
        remote = try container.decodeIfPresent(Bool.self, forKey: .remote)
        room = try container.decodeIfPresent(String.self, forKey: .room)
        startDateTime = try container.decodeIfPresent(String.self, forKey: .startDateTime)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        
        // Handle video array which may contain null values
        // Decode manually to filter out null values
        if container.contains(.video) {
            if try container.decodeNil(forKey: .video) {
                video = nil
            } else {
                var videoArray: [CommitteeVideo] = []
                var nestedContainer = try container.nestedUnkeyedContainer(forKey: .video)
                
                while !nestedContainer.isAtEnd {
                    // Check if current element is null first
                    if !(try nestedContainer.decodeNil()) {
                        // Not null, decode as CommitteeVideo
                        let videoItem = try nestedContainer.decode(CommitteeVideo.self)
                        videoArray.append(videoItem)
                    }
                    // If it was null, decodeNil() consumed it and we continue to next element
                }
                video = videoArray.isEmpty ? nil : videoArray
            }
        } else {
            video = nil
        }
    }
}

struct CommitteeVideo: Codable {
    let committee: String?
    let description: String?
    let endDateTime: String?
    let playerLink: String?
    let playerLinkIFrame: String?
    let room: String?
    let startDateTime: String?
    let title: String?
    let transcribe: Bool?
    let type: String?
    let unid: String?
    let videoLink: String?
}

// MARK: - Committee Details
struct CommitteeDetails: Codable {
    let appointmentDate: String?
    let code: String?
    let compositionDate: String?
    let members: [CommitteeMember]?
    let name: String?
    let nameGenitive: String?
    let phone: String?
    let scope: String?
    let subCommittees: [String]?
    let type: String?
}

struct CommitteeMember: Codable {
    let club: String?
    let function: String?
    let id: Int?
    let lastFirstName: String?
}

