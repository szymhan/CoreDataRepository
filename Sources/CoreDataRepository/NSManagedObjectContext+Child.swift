// NSManagedObjectContext+Child.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import CoreData
import Foundation

extension NSManagedObjectContext {
    func performInChild<Output>(
        _ block: @escaping (NSManagedObjectContext) throws -> Output
    ) async -> Result<Output, CoreDataRepositoryError> {
        let child = childContext()
        let output: Output
        do {
            output = try await performInChild(
                child: child,
                block: block
            )
            return .success(output)
        }
        catch let error as CoreDataRepositoryError {
            child.perform {
                child.rollback()
            }
            return .failure(error)
        } catch let error as NSError {
            child.perform {
                child.rollback()
            }
            return .failure(.coreData(error))
        }
    }

    func performInChild<Output>(
        child: NSManagedObjectContext,
        block: @escaping (NSManagedObjectContext) throws -> Output
    ) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            child.perform {
                do {
                    let result = try block(child)
                    continuation.resume(with: .success(result))
                }
                catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func childContext() -> NSManagedObjectContext {
        let child = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        child.automaticallyMergesChangesFromParent = true
        child.parent = self
        return child
    }
}
