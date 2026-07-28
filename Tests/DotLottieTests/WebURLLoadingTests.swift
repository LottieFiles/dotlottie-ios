import XCTest
@testable import DotLottie

/// Stubs `URLSession.shared` so the `webURL:` async-loading path can be tested
/// deterministically, without touching the network.
private final class StubURLProtocol: URLProtocol {
    struct Response { let status: Int; let data: Data }
    static var response: Response?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "stub.test"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        if let stub = Self.response {
            let http = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class WebURLLoadingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.response = nil
        super.tearDown()
    }

    func testWebURLLoadsJSON() {
        StubURLProtocol.response = .init(status: 200, data: Data(Fixtures.flowJSON.utf8))
        let animation = DotLottieAnimation(webURL: "https://stub.test/animation.json", config: AnimationConfig())
        XCTAssertTrue(waitUntilLoaded(animation), "web JSON should load")
        XCTAssertFalse(animation.error())
        XCTAssertGreaterThan(animation.totalFrames(), 0)
    }

    func testWebURLLoadsDotLottie() {
        StubURLProtocol.response = .init(status: 200, data: Fixtures.coffeeLottie)
        let animation = DotLottieAnimation(webURL: "https://stub.test/animation.lottie", config: AnimationConfig())
        XCTAssertTrue(waitUntilLoaded(animation), "web .lottie should load")
        XCTAssertGreaterThan(animation.totalFrames(), 0)
    }

    func testWebURLServerErrorSetsErrorFlag() {
        StubURLProtocol.response = .init(status: 500, data: Data())
        let animation = DotLottieAnimation(webURL: "https://stub.test/missing.json", config: AnimationConfig())
        // waitUntilLoaded returns once the animation reports loaded OR errored.
        _ = waitUntilLoaded(animation, timeout: 3)
        XCTAssertTrue(animation.error(), "a non-200 response should set the error flag")
        XCTAssertFalse(animation.isLoaded())
    }

    func testInvalidWebURLDoesNotCrash() {
        // Empty / malformed URL: the loader should no-op safely, not crash.
        let animation = DotLottieAnimation(webURL: "", config: AnimationConfig())
        _ = waitUntilLoaded(animation, timeout: 1)
        XCTAssertFalse(animation.isLoaded())
    }
}
