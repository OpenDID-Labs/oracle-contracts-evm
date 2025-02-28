// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOperator {
    event OperatorChanged(address operator, bool authorized);
    // @notice Sets the fulfillment permission for a given operator. Use `true` to allow, `false` to disallow.
    // @param operator The address of the authorized oracle node
    // emits event OperatorChanged
    function setOperator(address operator, bool authorized) external;

    // @notice Use this to check if a node is authorized for fulfilling requests.
    // @param operator The address of the oracle node
    // @return The authorization status of the node
    function isAuthorizedOperator(
        address operator
    ) external view returns (bool);
}
