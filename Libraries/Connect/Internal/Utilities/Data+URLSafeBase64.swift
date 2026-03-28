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

import Foundation

extension Data {
    /// Returns a raw URL-safe base64 encoded string (RFC 4648 §5).
    ///
    /// Uses native `base64URLAlphabet` + `omitPaddingCharacter` on platforms
    /// that support it (iOS 26.4+, macOS 26.4+), with a string-replacement
    /// fallback for older OS versions.
    func urlSafeBase64EncodedString() -> String {
        if #available(iOS 26.4, macOS 26.4, watchOS 26.4, tvOS 26.4, visionOS 26.4, *) {
            return self.base64EncodedString(options: [.base64URLAlphabet, .omitPaddingCharacter])
        } else {
            return self.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }
}
