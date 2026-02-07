// OutpostRuntime - Simulation engine and manager systems
//
// Re-exports OutpostCore and OutpostWorldGen for convenient access by consumers.

@_exported import OutpostCore
@_exported import OutpostWorldGen

// Resolve ambiguity between OutpostCore.Unit and Foundation.NSUnit
public typealias Unit = OutpostCore.Unit
