// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOperatorInterface.sol";

abstract contract Operator is IOperatorInterface {
    mapping(address operator => bool authorized) private operators;

    /**
     *  @dev See {IOperatorInterface-setOperator}.
     */
    function setOperator(
        address operator,
        bool authorized
    ) external override authorizedOperatorSetter {
        require(operator != address(0), "Non zero address");
        require(operators[operator] != authorized, "Invalid operation");
        operators[operator] = authorized;
        emit OperatorChanged(operator, authorized);
    }

    /**
     *  @dev See {IOperatorInterface-isAuthorizedOperator}.
     */
    function isAuthorizedOperator(
        address operator
    ) public view override returns (bool) {
        return operators[operator];
    }

    // @notice customizable guard of who can update the authorized operator list
    // @return bool whether sender can update authorized operator list
    function _canSetOperator() internal view virtual returns (bool);
    // @notice prevents non-authorized addresses from calling this method
    modifier authorizedOperatorSetter() {
        require(_canSetOperator(), "Cannot set operator");
        _;
    }

    // @notice validates the sender is an authorized operator
    modifier authorizedOperator() {
        require(isAuthorizedOperator(msg.sender), "Not authorized operator");
        _;
    }
}
