import XCTest

@testable import HermesControl

final class HelpersTests: XCTestCase {

  // MARK: extract() — the regex helper used to parse gateway log lines

  func testExtractCapturesFirstGroup() {
    let line = "inbound message: platform=telegram user=Marco Jang chat=8327969024 msg='hello'"
    XCTAssertEqual(extract("platform=(\\w+)", from: line), "telegram")
    XCTAssertEqual(extract("msg='(.*)'", from: line), "hello")
  }

  func testExtractReturnsNilWhenNoMatch() {
    XCTAssertNil(extract("platform=(\\w+)", from: "no platform here"))
    XCTAssertNil(extract("(\\d+)", from: "abc"))
  }

  func testExtractUserBetweenMarkers() {
    let line = "user=Marco Jang chat=123"
    XCTAssertEqual(extract("user=(.+?) chat=", from: line), "Marco Jang")
  }

  // MARK: ModelOption.isValid — the injection guard for config writes

  func testValidModelOptionAccepted() {
    let ok = ModelOption(
      id: "custom:mlx-community/Qwen3-32B-4bit",
      modelId: "mlx-community/Qwen3-32B-4bit",
      provider: "custom",
      baseUrl: "http://127.0.0.1:8080/v1")
    XCTAssertTrue(ok.isValid)
  }

  func testEmptyBaseURLAllowed() {
    let codex = ModelOption(id: "openai-codex:gpt-5.5", modelId: "gpt-5.5", provider: "openai-codex", baseUrl: "")
    XCTAssertTrue(codex.isValid)
  }

  func testInjectionAttemptsRejected() {
    // Quote/space/path-traversal payloads that would break the config write must be refused.
    let quoteInModel = ModelOption(id: "x", modelId: "gpt'; import os", provider: "custom", baseUrl: "")
    let spaceInProvider = ModelOption(id: "x", modelId: "gpt", provider: "a b", baseUrl: "")
    let badURL = ModelOption(id: "x", modelId: "gpt", provider: "custom", baseUrl: "http://x'$(rm -rf)")
    XCTAssertFalse(quoteInModel.isValid)
    XCTAssertFalse(spaceInProvider.isValid)
    XCTAssertFalse(badURL.isValid)
  }

  // MARK: findExecutable() — tool discovery used for the hermes CLI

  func testFindExecutableLocatesKnownBinary() {
    // /bin/sh exists on every macOS; discovery must find it.
    XCTAssertEqual(findExecutable("sh"), "/bin/sh")
  }

  func testFindExecutableReturnsNilForMissing() {
    XCTAssertNil(findExecutable("definitely-not-a-real-binary-xyz123"))
  }
}
