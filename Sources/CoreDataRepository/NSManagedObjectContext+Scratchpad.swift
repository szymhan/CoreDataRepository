// NSManagedObjectContext+Scratchpad.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import Combine
import CoreData
import Foundation

extension NSManagedObjectContext {
    public func performInScratchPad<Output>(
        _ block: @escaping (NSManagedObjectContext) throws -> Output
    ) async -> Result<Output, CoreDataRepositoryError> {
        let scratchPad = scratchPadContext()
        do {
            let output: Output = try await performInScratchPad(
                context: scratchPad,
                block: block
            )
            return .success(output)
        }
        catch let error as CoreDataRepositoryError {
            scratchPad.perform {
                scratchPad.rollback()
            }
            return .failure(error)
        } catch let error as NSError {
            scratchPad.perform {
                scratchPad.rollback()
            }
            return .failure(.coreData(error))
        }
    }

    func performInScratchPad<Output>(
        context: NSManagedObjectContext,
        block: @escaping (NSManagedObjectContext) throws -> Output
    ) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(context)
                    continuation.resume(with: .success(result))
                }
                catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func performAndWaitInScratchPad<Output>(
        promise: @escaping Future<Output, CoreDataRepositoryError>.Promise,
        _ block: @escaping (NSManagedObjectContext) -> Result<Output, CoreDataRepositoryError>
    ) throws {
        let scratchPad = scratchPadContext()
        scratchPad.performAndWait {
            let result = block(scratchPad)
            if case .failure = result {
                scratchPad.rollback()
            }
            promise(result)
        }
    }

    private func scratchPadContext() -> NSManagedObjectContext {
        let scratchPad = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        scratchPad.automaticallyMergesChangesFromParent = false
        scratchPad.parent = self
        return scratchPad
    }
}
