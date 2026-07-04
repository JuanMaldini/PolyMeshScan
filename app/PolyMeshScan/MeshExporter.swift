import ARKit

/// Exporta ARMeshAnchors a un OBJ simple (vertices + caras, sin textura).
/// Suficiente para v1; texturizado/optimizacion es trabajo del pipeline (Fase 2).
enum MeshExporter {
    /// Devuelve la cantidad total de vertices exportados.
    static func exportOBJ(meshes: [ARMeshAnchor], to url: URL) throws -> Int {
        var obj = "# PolyMeshScan raw mesh export\n"
        var vertexOffset = 0
        var totalVertices = 0

        for anchor in meshes {
            let geo = anchor.geometry
            let transform = anchor.transform

            // Vertices (en coordenadas de mundo)
            let vertices = geo.vertices
            for i in 0..<vertices.count {
                let v = vertices.buffer.contents()
                    .advanced(by: vertices.offset + vertices.stride * i)
                    .assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let world = transform * SIMD4<Float>(v.x, v.y, v.z, 1)
                obj += "v \(world.x) \(world.y) \(world.z)\n"
            }

            // Caras (triangulos, indices 1-based en OBJ)
            let faces = geo.faces
            let indexSize = faces.bytesPerIndex
            for f in 0..<faces.count {
                var idx = [Int](repeating: 0, count: 3)
                for c in 0..<3 {
                    let ptr = faces.buffer.contents()
                        .advanced(by: (f * 3 + c) * indexSize)
                    idx[c] = indexSize == 4
                        ? Int(ptr.assumingMemoryBound(to: UInt32.self).pointee)
                        : Int(ptr.assumingMemoryBound(to: UInt16.self).pointee)
                }
                obj += "f \(idx[0] + 1 + vertexOffset) \(idx[1] + 1 + vertexOffset) \(idx[2] + 1 + vertexOffset)\n"
            }

            vertexOffset += vertices.count
            totalVertices += vertices.count
        }

        try obj.write(to: url, atomically: true, encoding: .utf8)
        return totalVertices
    }
}
