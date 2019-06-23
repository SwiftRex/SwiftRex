//
//  TypeErasureTests.swift
//  SwiftRex
//
//  Created by Luiz Rodrigo Martins Barbosa on 22.06.19.
//

import Foundation
import Nimble
@testable import SwiftRex
import XCTest

class TypeErasureTests: XCTestCase {
    func testMiddlewareBaseInitThrows() {
        expect { _ = _AnyMiddlewareBase<TestState>() }.to(throwAssertion())
    }

    func testMiddlewareBaseHandleEventThrows() {
        let sut = MiddlewareAbstract<TestState>()
        expect {
            sut.handle(event: Event1(), getState: { TestState() }, next: { _, _ in })
        }.to(throwAssertion())
    }

    func testMiddlewareBaseHandleActionThrows() {
        let sut = MiddlewareAbstract<TestState>()
        expect {
            sut.handle(action: Action1(), getState: { TestState() }, next: { _, _ in })
        }.to(throwAssertion())
    }

    func testMiddlewareBaseHandlerGetThrows() {
        let sut = MiddlewareAbstract<TestState>()
        expect {
            _ = sut.handlers
        }.to(throwAssertion())
    }

    func testMiddlewareBaseHandlerSetThrows() {
        let sut = MiddlewareAbstract<TestState>()
        expect {
            sut.handlers = .init(actionHandler: ActionHandler(), eventHandler: EventHandler())
        }.to(throwAssertion())
    }

    func testSideEffectProducerBaseInitThrows() {
        expect { _ = _AnySideEffectProducerBase<TestState>() }.to(throwAssertion())
    }

    func testSideEffectProducerBaseExecuteThrows() {
        let sut = SideEffectProducerAbstract<TestState>()
        expect { _ = sut.execute(getState: { TestState() }) }.to(throwAssertion())
    }
}

class MiddlewareAbstract<T>: _AnyMiddlewareBase<T> {
}

class SideEffectProducerAbstract<T>: _AnySideEffectProducerBase<T> {
}