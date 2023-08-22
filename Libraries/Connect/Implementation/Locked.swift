// Copyright 2022-2023 Buf Technologies, Inc.
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

final class Locked<T>: @unchecked Sendable {
    private let lock = Lock()
    private var _value: T

    var value: T {
        get { self.lock.perform { self._value } }
        set { self.lock.perform { self._value = newValue } }
    }

    func perform(action: @escaping (inout T) -> Void) {
        self.lock.perform {
            action(&self._value)
        }
    }

    init(_ value: T) {
        self._value = value
    }
}
