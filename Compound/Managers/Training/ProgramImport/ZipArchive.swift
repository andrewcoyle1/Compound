//
//  ZipArchive.swift
//  Compound
//
//  The few zip entries an `.xlsx` needs, read by name. Stored entries are copied and deflated
//  ones inflated with `Compression` (`COMPRESSION_ZLIB` decodes raw DEFLATE, which is what a zip
//  holds). Sizes come from the central directory, so entries written with a data descriptor read
//  the same.
//

import Compression
import Foundation

struct ZipArchive {

    private struct Entry {
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data
    private let entries: [String: Entry]

    /// Fails when `data` is not a zip. ponytail: no ZIP64, which only files over 4 GB need.
    init(data: Data) throws {
        self.data = data
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { throw ProgramImportError.unreadableFile }

        // The end-of-central-directory record is the last 22 bytes plus any comment.
        var end = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 0xFFFF)
        while end >= lowest, Self.uint32(bytes, end) != 0x0605_4B50 { end -= 1 }
        guard end >= lowest else { throw ProgramImportError.unreadableFile }

        let count = Int(Self.uint16(bytes, end + 10))
        var offset = Int(Self.uint32(bytes, end + 16))
        var entries: [String: Entry] = [:]
        for _ in 0..<count {
            guard offset + 46 <= bytes.count, Self.uint32(bytes, offset) == 0x0201_4B50 else {
                throw ProgramImportError.unreadableFile
            }
            let nameLength = Int(Self.uint16(bytes, offset + 28))
            let extraLength = Int(Self.uint16(bytes, offset + 30))
            let commentLength = Int(Self.uint16(bytes, offset + 32))
            guard offset + 46 + nameLength <= bytes.count else { throw ProgramImportError.unreadableFile }
            let name = String(bytes: bytes[(offset + 46)..<(offset + 46 + nameLength)], encoding: .utf8) ?? ""
            entries[name] = Entry(
                method: Self.uint16(bytes, offset + 10),
                compressedSize: Int(Self.uint32(bytes, offset + 20)),
                uncompressedSize: Int(Self.uint32(bytes, offset + 24)),
                localHeaderOffset: Int(Self.uint32(bytes, offset + 42))
            )
            offset += 46 + nameLength + extraLength + commentLength
        }
        self.entries = entries
    }

    /// The entry's contents, or nil when the archive has no entry by that name.
    func entry(_ name: String) throws -> Data? {
        guard let entry = entries[name] else { return nil }
        let header = entry.localHeaderOffset
        guard header + 30 <= data.count else { throw ProgramImportError.unreadableFile }
        let bytes = data.withUnsafeBytes { Array($0[header..<(header + 30)]) }
        let start = header + 30 + Int(Self.uint16(bytes, 26)) + Int(Self.uint16(bytes, 28))
        guard start + entry.compressedSize <= data.count else { throw ProgramImportError.unreadableFile }
        let compressed = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + entry.compressedSize))

        switch entry.method {
        case 0:
            return compressed
        case 8:
            return try Self.inflate(compressed, size: entry.uncompressedSize)
        default:
            throw ProgramImportError.unreadableFile
        }
    }

    private static func inflate(_ compressed: Data, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { destination -> Int in
            compressed.withUnsafeBytes { source -> Int in
                guard let target = destination.bindMemory(to: UInt8.self).baseAddress,
                      let origin = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(target, size, origin, compressed.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ProgramImportError.unreadableFile }
        return output
    }

    private static func uint16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func uint32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(uint16(bytes, offset)) | UInt32(uint16(bytes, offset + 2)) << 16
    }
}
