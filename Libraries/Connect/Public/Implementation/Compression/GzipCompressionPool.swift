// Copyright 2022-2024 The Connect Authors
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

import Foundation
import zlib

/// Compression pool that handles gzip compression/decompression.
public struct GzipCompressionPool: Sendable {
    public init() {}

    public enum GzipError: Error {
        case failedToInitialize
        case failedToFinish
    }
}

extension GzipCompressionPool: CompressionPool {
    public func name() -> String {
        return "gzip"
    }

    public func compress(data: Data) throws -> Data {
        if data.isEmpty || data.isGzipped() {
            return data
        }

        var stream = z_stream()
        var status: Int32 = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            MAX_WBITS + 16,
            MAX_MEM_LEVEL,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        if status != Z_OK {
            throw GzipError.failedToInitialize
        }

        let chunkSize = 16_384 // Standard chunk size
        var output = Data(capacity: chunkSize)
        repeat {
            if stream.total_out >= output.count {
                output.count += chunkSize
            }

            let inputCount = data.count
            let outputCount = output.count

            data.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer<Bytef>(
                    mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!
                ).advanced(by: Int(stream.total_in))
                stream.avail_in = UInt32(inputCount) - UInt32(stream.total_in)

                output.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
                    stream.next_out = outputPointer.bindMemory(to: Bytef.self)
                        .baseAddress!.advanced(by: Int(stream.total_out))
                    stream.avail_out = UInt32(outputCount) - UInt32(stream.total_out)
                    status = deflate(&stream, Z_FINISH)
                    stream.next_out = nil
                }
                stream.next_in = nil
            }
        } while stream.avail_out == 0

        if deflateEnd(&stream) != Z_OK || status != Z_STREAM_END {
            throw GzipError.failedToFinish
        }

        output.count = Int(stream.total_out)
        return output
    }

    public func decompress(data: Data) throws -> Data {
        if data.isEmpty || !data.isGzipped() {
            return data
        }

        var stream = z_stream()
        var status: Int32 = inflateInit2_(
            &stream,
            MAX_WBITS + 32,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        if status != Z_OK {
            throw GzipError.failedToInitialize
        }

        var output = Data(capacity: data.count * 2)
        repeat {
            if stream.total_out >= output.count {
                output.count += data.count / 2
            }

            let inputCount = data.count
            let outputCount = output.count

            data.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer<Bytef>(
                    mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!
                ).advanced(by: Int(stream.total_in))
                stream.avail_in = UInt32(inputCount) - UInt32(stream.total_in)

                output.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
                    stream.next_out = outputPointer.bindMemory(to: Bytef.self)
                        .baseAddress!.advanced(by: Int(stream.total_out))
                    stream.avail_out = UInt32(outputCount) - UInt32(stream.total_out)
                    status = inflate(&stream, Z_SYNC_FLUSH)
                    stream.next_out = nil
                }

                stream.next_in = nil
            }
        } while status == Z_OK

        if inflateEnd(&stream) != Z_OK || status != Z_STREAM_END {
            throw GzipError.failedToFinish
        }

        output.count = Int(stream.total_out)
        return output
    }
}

private extension Data {
    func isGzipped() -> Bool {
        return self.starts(with: [0x1f, 0x8b])
    }
}
