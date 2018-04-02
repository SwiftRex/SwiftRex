//
//  GitHubSearchRepositoriesAPI.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 10/18/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// Adapted from Official RxSwift example:
// https://github.com/ReactiveX/RxSwift/blob/master/RxExample/RxExample/Examples/GitHubSearchRepositories/GitHubSearchRepositoriesAPI.swift

import RxSwift

import struct Foundation.URL
import struct Foundation.Data
import struct Foundation.URLRequest
import struct Foundation.NSRange
import class Foundation.HTTPURLResponse
import class Foundation.URLSession
import class Foundation.NSRegularExpression
import class Foundation.JSONSerialization
import class Foundation.NSString
import class Foundation.URLSession
import class Foundation.OperationQueue
import enum Foundation.QualityOfService

protocol GitHubServiceError: Error {
}

enum GitHubAPIError: GitHubServiceError {
    case offline
    case githubLimitReached
    case networkError
    case wrongResponseCode(Int)
}

enum GitHubParserError: GitHubServiceError {
    case invalidResponseBody
    case linksError
    case nextPageError(String)
    case itemsNotFound
    case repositoryError
}

typealias SearchRepositoriesResponse = Result<(repositories: [Repository], nextURL: URL?)>

class GitHubSearchRepositoriesAPI {

    // *****************************************************************************************
    // !!! This is defined for simplicity sake, using singletons isn't advised               !!!
    // !!! This is just a simple way to move services to one location so you can see Rx code !!!
    // *****************************************************************************************
    static let sharedAPI = GitHubSearchRepositoriesAPI(reachabilityService: try! DefaultReachabilityService())

    fileprivate let _reachabilityService: ReachabilityService

    private init(reachabilityService: ReachabilityService) {
        _reachabilityService = reachabilityService
    }
}

extension GitHubSearchRepositoriesAPI {
    static var backgroundWorkScheduler: ImmediateSchedulerType = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 2
        operationQueue.qualityOfService = QualityOfService.userInitiated
        return OperationQueueScheduler(operationQueue: operationQueue)
    }()

    public func loadSearchURL(_ searchURL: URL) -> Observable<SearchRepositoriesResponse> {
        return URLSession.shared
            .rx.response(request: URLRequest(url: searchURL))
            .retry(3)
            .observeOn(GitHubSearchRepositoriesAPI.backgroundWorkScheduler)
            .map { pair -> SearchRepositoriesResponse in
                if pair.0.statusCode == 403 {
                    return .failure(GitHubAPIError.githubLimitReached)
                }

                let jsonRoot = try GitHubSearchRepositoriesAPI.parseJSON(pair.0, data: pair.1)

                guard let json = jsonRoot as? [String: AnyObject] else {
                    throw GitHubParserError.invalidResponseBody
                }

                let repositories = try Repository.parse(json)

                let nextURL = try GitHubSearchRepositoriesAPI.parseNextURL(pair.0)

                return .success((repositories: repositories, nextURL: nextURL))
            }
            .retryOnBecomesReachable(.failure(GitHubAPIError.offline), reachabilityService: _reachabilityService)
    }
}

// MARK: Parsing the response

extension GitHubSearchRepositoriesAPI {

    private static let parseLinksPattern = "\\s*,?\\s*<([^\\>]*)>\\s*;\\s*rel=\"([^\"]*)\""
    private static let linksRegex = try! NSRegularExpression(pattern: parseLinksPattern, options: [.allowCommentsAndWhitespace])

    fileprivate static func parseLinks(_ links: String) throws -> [String: String] {

        let length = (links as NSString).length
        let matches = GitHubSearchRepositoriesAPI.linksRegex.matches(in: links, options: NSRegularExpression.MatchingOptions(), range: NSRange(location: 0, length: length))

        var result: [String: String] = [:]

        for m in matches {
            let matches = (1 ..< m.numberOfRanges).map { rangeIndex -> String in
                let range = m.range(at: rangeIndex)
                let startIndex = links.index(links.startIndex, offsetBy: range.location)
                let endIndex = links.index(links.startIndex, offsetBy: range.location + range.length)
                return String(links[startIndex ..< endIndex])
            }

            if matches.count != 2 {
                throw GitHubParserError.linksError
            }

            result[matches[1]] = matches[0]
        }

        return result
    }

    fileprivate static func parseNextURL(_ httpResponse: HTTPURLResponse) throws -> URL? {
        guard let serializedLinks = httpResponse.allHeaderFields["Link"] as? String else {
            return nil
        }

        let links = try GitHubSearchRepositoriesAPI.parseLinks(serializedLinks)

        guard let nextPageURL = links["next"] else {
            return nil
        }

        guard let nextUrl = URL(string: nextPageURL) else {
            throw GitHubParserError.nextPageError(nextPageURL)
        }

        return nextUrl
    }

    fileprivate static func parseJSON(_ httpResponse: HTTPURLResponse, data: Data) throws -> AnyObject {
        if !(200 ..< 300 ~= httpResponse.statusCode) {
            throw GitHubAPIError.wrongResponseCode(httpResponse.statusCode)
        }

        return try JSONSerialization.jsonObject(with: data, options: []) as AnyObject
    }

}

extension Repository {
    fileprivate static func parse(_ json: [String: AnyObject]) throws -> [Repository] {
        guard let items = json["items"] as? [[String: AnyObject]] else {
            throw GitHubParserError.itemsNotFound
        }
        return try items.map { item in
            guard let name = item["name"] as? String,
                let urlString = item["url"] as? String,
                let url = URL(string: urlString) else {
                    throw GitHubParserError.repositoryError
            }
            return Repository(name: name, url: url)
        }
    }
}
