## ConnectMocks

This module contains types that are designed to make mocking/testing generated
Connect clients and methods easier.

The typical workflow for consuming these mocks is:

1. Invoke the `connect-swift-mocks` plugin.
2. The plugin will output corresponding `*.mock.swift` files which import `ConnectMocks` to provide default no-op implementations for each generated `service` and `rpc`.
3. Import both the `ConnectMocks` module and the generated files into your test suite.
4. Assuming your code uses the `*Interface` types (rather than their concrete implementation types), you can inject the corresponding `*Mock` types (instead of the generated `*Client` types as you would in production) and easily replace production RPC calls with mocked out test data.
