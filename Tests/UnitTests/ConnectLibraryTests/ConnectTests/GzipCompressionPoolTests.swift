// Copyright 2022-2025 The Connect Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Connect
import Foundation
import Testing

struct GzipCompressionPoolTests {
    @Test("GzipCompressionPool correctly decompresses pre-compressed gzip files")
    func decompressingGzippedFile() throws {
        let compressedData = try self.gzippedFileData()
        let decompressedText = try #require(String(
            data: try GzipCompressionPool().decompress(data: compressedData),
            encoding: .utf8
        ))
        #expect(decompressedText == self.expectedUnzippedFileText())
    }

    @Test("GzipCompressionPool can compress data and then decompress it back to original")
    func compressingAndDecompressingData() throws {
        let original = try #require(self.expectedUnzippedFileText().data(using: .utf8))
        let compressionPool = GzipCompressionPool()
        let compressed = try compressionPool.compress(data: original)
        #expect(compressed.starts(with: [0x1f, 0x8b])) // Indicates gzip
        #expect(compressed.count != original.count)

        let decompressed = try compressionPool.decompress(data: compressed)
        #expect(decompressed == original)
    }

    @Test("GzipCompressionPool skips compression when data is already gzip compressed")
    func doesNotGzipDataThatIsAlreadyGzipped() throws {
        let compressed = try self.gzippedFileData()
        let recompressed = try GzipCompressionPool().compress(data: compressed)
        #expect(compressed == recompressed)
    }

    // MARK: - Private

    private func expectedUnzippedFileText() -> String {
        return "the quiccccccck brown fox juuuuuuuuuumps over the lazy doggggggggggggggg\n"
    }

    private func gzippedFileData() throws -> Data {
        let gzippedFileURL = try #require(
            Bundle.module.url(
                forResource: "gzip-test.txt.gz", withExtension: nil, subdirectory: "TestResources"
            )
        )
        return try Data(contentsOf: gzippedFileURL)
    }
}
