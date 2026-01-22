//===--- Gyb.swift --------------------------------------------------------===//
//
// This source file is part of the swift-library open source project
//
// Created by Xudong Xu on 5/2/23.
//
// Copyright (c) 2023 Xudong Xu <showxdxu@gmail.com> and the swift-library project authors
//
// See https://swift-library.github.io/LICENSE.txt for license information
// See https://swift-library.github.io/CONTRIBUTORS.txt for the list of swift-library project authors
// See https://github.com/swift-library for the list of swift-library projects
//
//===----------------------------------------------------------------------===//

import PackagePlugin

@main
struct GybBuildPlugin: BuildToolPlugin {
  
  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    let toolPath = try context.tool(named: "gyb").path
    
    // Get compilation conditions if this is a Swift target
    let compilationConditions: [String]
    if let swiftTarget = target as? SwiftSourceModuleTarget {
      compilationConditions = swiftTarget.compilationConditions
    } else {
      compilationConditions = []
    }
    
    let gyb: (_ src: Path, _ dst: Path) -> Command = {
      .buildCommand(
        displayName: "Using gyb convert \($0.lastComponent) to \($1.lastComponent)",
        executable: toolPath,
        arguments: compilationConditions.flatMap { ["-D", "\($0)=1"] } + [
          "--line-directive", #"#sourceLocation(file: "%(file)s", line: %(line)d)"#,
          "-o", $1,
          $0,
        ],
        inputFiles: [$0],
        outputFiles: [$1])
    }
    
    let outputPath: (Path) -> (Path) = {
      // Strip .gyb extension, keeping the underlying extension (e.g., .swift, .metal)
      context.pluginWorkDirectory.appending($0.stem)
    }
    
    // Handle both Swift and Clang targets
    let gybFiles: [File]
    if let swiftTarget = target as? SwiftSourceModuleTarget {
      gybFiles = Array(swiftTarget.sourceFiles(withSuffix: ".gyb"))
    } else if let clangTarget = target as? ClangSourceModuleTarget {
      // Debug: list all source files
      Diagnostics.remark("ClangTarget \(target.name) sourceFiles: \(clangTarget.sourceFiles.map { $0.path.string })")
      gybFiles = clangTarget.sourceFiles.filter { $0.path.extension == "gyb" }
    } else {
      return []
    }
    
    return gybFiles.map { ($0.path, outputPath($0.path)) }.map(gyb)
  }
}
