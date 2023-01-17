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

/// Interface for options that can be used to configure `ProtocolClientInterface` implementations.
/// External consumers can adopt this protocol to implement custom configurations.
public protocol ProtocolClientOption {
    /// Invoked by `ProtocolClientInterface` implementations allowing the option to mutate the
    /// configuration for the client.
    ///
    /// - parameter config: The current client configuration.
    ///
    /// - returns: The updated client configuration, with settings from this client option applied.
    func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig
}
