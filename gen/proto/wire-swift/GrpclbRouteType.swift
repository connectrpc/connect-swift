// Code generated by Wire protocol buffer compiler, do not edit.
// Source: grpc.testing.GrpclbRouteType in grpc/testing/messages.proto
/**
 *  The type of route that a client took to reach a server w.r.t. gRPCLB.
 *  The server must fill in "fallback" if it detects that the RPC reached
 *  the server via the "gRPCLB fallback" path, and "backend" if it detects
 *  that the RPC reached the server via "gRPCLB backend" path (i.e. if it got
 *  the address of this server from the gRPCLB server BalanceLoad RPC). Exactly
 *  how this detection is done is context and server dependent.
 */
public enum GrpclbRouteType : UInt32, CaseIterable, Codable {

    /**
     *  Server didn't detect the route that a client took to reach it.
     */
    case GRPCLB_ROUTE_TYPE_UNKNOWN = 0
    /**
     *  Indicates that a client reached a server via gRPCLB fallback.
     */
    case GRPCLB_ROUTE_TYPE_FALLBACK = 1
    /**
     *  Indicates that a client reached a server as a gRPCLB-given backend.
     */
    case GRPCLB_ROUTE_TYPE_BACKEND = 2

}
