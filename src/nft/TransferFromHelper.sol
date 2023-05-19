// SPDX-License-Identifier: GPL-3.0
// Acknowledgement: This contract was directly modified from uniswap-v3 library TransferHelper.sol
pragma solidity ^0.8.17;

import "@transmissions11/solmate/src/tokens/ERC20.sol";

/// @title TransferFromHelper
/// @notice Contains helper methods for interacting with ERC20 tokens that do not consistently return true/false
library TransferFromHelper {
    /// @notice Transfers tokens from 'src' to the recipient address 'dst'
    /// @dev Calls transferFrom on token contract, errors with TF if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param src The source address of the transfer
    /// @param dst The destination address of the transfer
    /// @param value The value of the transfer
    
    function safeTransferFrom(
        address token,
        address src,
        address dst,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(ERC20.transferFrom.selector, src, dst, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TF');
    }
}